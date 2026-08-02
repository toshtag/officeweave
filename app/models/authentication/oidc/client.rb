require "net/http"
require "json"
require "uri"

module Authentication
  module Oidc
    # 認可サーバーとの通信。
    #
    # 発見の経路から端点と鍵の場所を読み、code を id_token へ交換する。
    # 相手の応答をどこまで信じるかを、ここで決める。
    #
    # 端点は発見の応答が決める。応答をそのまま使うと、認可の宛先と token の
    # 宛先を相手が自由に指せる。同じ発行者の下にある https の URL だけを認める。
    class Client
      # 認可サーバーとのやり取りが成立しなかった。
      # 文面へは、送った値と受け取った本文を入れない。記録へ資格情報が写る。
      class ProviderError < StandardError; end

      # 受け取る量の上限。
      # 発見の応答も鍵の一覧も数 KB である。桁が違う応答は相手の異常とみなす。
      RESPONSE_LIMIT = 256 * 1024

      OPEN_TIMEOUT = 5
      READ_TIMEOUT = 5

      # 要求する範囲。利用者の突き合わせに使うのはメールアドレスだけである。
      SCOPE = "openid email".freeze

      # 発見の結果を持ち続ける時間。
      #
      # ログインのたびに 2 往復増えると、認可サーバーへの負荷が利用回数に
      # 比例する。一方で、鍵の入れ替えへ追随できなくなるほど長くは持たない。
      CACHE_TTL = 1.hour

      # 発見の応答へ必ずあることを求める項目。
      REQUIRED_ENDPOINTS = %w[authorization_endpoint token_endpoint jwks_uri].freeze

      # 名前解決と証明書の検証元は、テストから差し替える。
      # インスタンスの中に閉じ、他の呼び出しへ漏れる状態を作らない。
      attr_writer :certificate_store, :resolver

      class << self
        # 発見の結果は、この処理系の中で共有する。
        def cache = @cache ||= {}

        # テストから呼ぶ。共有した結果を持ち越すと、往復の回数を確かめられない。
        def reset_cache! = @cache = {}
      end

      def initialize(settings)
        @settings = settings
      end

      def authorization_endpoint = endpoint("authorization_endpoint")
      def token_endpoint = endpoint("token_endpoint")

      def jwks
        @jwks ||= fetch_json(verified_uri(endpoint("jwks_uri")))
      end

      # 認可の宛先。
      #
      # state と nonce は呼出側が作る。作る場所を分けると、要求と応答の
      # 対応を確かめる側が、確かめる値を知らないことになる。
      def authorization_url(redirect_uri:, state:, nonce:, code_challenge:)
        uri = verified_uri(authorization_endpoint)
        uri.query = URI.encode_www_form(
          response_type: "code",
          client_id: @settings.client_id,
          redirect_uri: redirect_uri,
          scope: SCOPE,
          state: state,
          nonce: nonce,
          # 交換のときに検証用の値を示す。code を横取りされても交換できない。
          code_challenge: code_challenge,
          code_challenge_method: "S256"
        )

        uri.to_s
      end

      # code を id_token へ交換する。
      #
      # client_secret は Basic 認証で送る。本文へ入れると、経路の記録へ
      # 残りやすい場所へ秘密を置くことになる。
      def exchange_code(code:, redirect_uri:, code_verifier:)
        response = post_form(
          verified_uri(token_endpoint),
          grant_type: "authorization_code",
          code: code,
          redirect_uri: redirect_uri,
          code_verifier: code_verifier
        )

        id_token = response["id_token"]
        raise ProviderError, "token の応答に id_token がありません" if id_token.blank?

        id_token
      end

      private
        def metadata
          cached = self.class.cache[@settings.issuer]
          return cached[:metadata] if cached && cached[:at] > Time.current - CACHE_TTL

          fetch_metadata.tap do |document|
            self.class.cache[@settings.issuer] = { metadata: document, at: Time.current }
          end
        end

        def fetch_metadata
          document = fetch_json(URI.parse(@settings.discovery_url))

          # 名乗る発行者が設定と違えば、その先の端点は信じられない。
          unless document["issuer"] == @settings.issuer
            raise ProviderError, "発見の応答の issuer が設定と一致しません"
          end

          missing = REQUIRED_ENDPOINTS.reject { |name| document[name].is_a?(String) }
          raise ProviderError, "発見の応答に #{missing.join(', ')} がありません" if missing.any?

          # 端点は読んだ時点で確かめる。使うときに確かめる形にすると、
          # 確かめずに使える経路が後から増える。
          REQUIRED_ENDPOINTS.each { |name| verified_uri(document.fetch(name)) }

          document
        end

        def endpoint(name) = metadata.fetch(name)

        # 端点は、同じ発行者の下にある https の URL だけを認める。
        #
        # 発見の応答が別の相手を指していれば、認可の宛先も token の宛先も
        # その相手になる。発行者の確認だけでは、そこを防げない。
        def verified_uri(value)
          uri = URI.parse(value)

          unless uri.is_a?(URI::HTTPS) && "#{uri.scheme}://#{uri.host}#{":#{uri.port}" if explicit_port?(uri)}" ==
                 issuer_origin
            raise ProviderError, "端点が発行者の下にありません"
          end

          uri
        rescue URI::InvalidURIError
          raise ProviderError, "端点として読み取れません"
        end

        def explicit_port?(uri) = uri.port != uri.default_port

        def issuer_origin
          @issuer_origin ||= begin
            uri = URI.parse(@settings.issuer)
            "#{uri.scheme}://#{uri.host}#{":#{uri.port}" if explicit_port?(uri)}"
          end
        end

        def fetch_json(uri)
          request = Net::HTTP::Get.new(uri)
          request["Accept"] = "application/json"

          parse_json(perform(uri, request))
        end

        def post_form(uri, **form)
          request = Net::HTTP::Post.new(uri)
          request["Accept"] = "application/json"
          request.basic_auth(@settings.client_id, @settings.client_secret)
          request.set_form_data(**form)

          parse_json(perform(uri, request))
        end

        # 応答の本文を、上限を超えたところで読むのをやめて返す。
        #
        # 上限を超えてから捨てる形にすると、捨てるまでの量を相手が決められる。
        # 読みながら数え、超えた時点で接続を切る。
        #
        # 転送（3xx）には従わない。従うと、発行者の下にあることを確かめた
        # 宛先から、別の相手へ移り得る。
        def perform(uri, request)
          body = +""

          connection(uri).start do |http|
            http.request(request) do |response|
              unless response.is_a?(Net::HTTPSuccess)
                raise ProviderError, "認可サーバーが #{response.code} を返しました"
              end

              response.read_body do |chunk|
                body << chunk
                raise ProviderError, "応答が大きすぎます" if body.bytesize > RESPONSE_LIMIT
              end
            end
          end

          body
        rescue ProviderError
          raise
        rescue OpenSSL::SSL::SSLError
          raise ProviderError, "認可サーバーとの暗号化された通信を確立できません"
        rescue Timeout::Error, SocketError, SystemCallError, IOError, Net::HTTPBadResponse => error
          raise ProviderError, "認可サーバーへ到達できません (#{error.class.name.demodulize})"
        end

        def parse_json(body)
          parsed = JSON.parse(body)
          raise ProviderError, "応答が JSON の対象ではありません" unless parsed.is_a?(Hash)

          parsed
        rescue JSON::ParserError
          raise ProviderError, "応答を JSON として読み取れません"
        end

        def connection(uri)
          # 第 3 引数へ nil を渡し、http_proxy などの環境変数を使わない。
          Net::HTTP.new(uri.hostname, uri.port, nil).tap do |http|
            http.open_timeout = OPEN_TIMEOUT
            http.read_timeout = READ_TIMEOUT
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_PEER
            http.verify_hostname = true
            http.max_retries = 0
            # 未指定なら Net::HTTP の既定に従う。この接続の中だけへ渡す。
            http.cert_store = @certificate_store if @certificate_store
            http.ipaddr = @resolver.call(uri.hostname) if @resolver
          end
        end
    end
  end
end
