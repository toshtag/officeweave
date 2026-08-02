require "uri"

module Officeweave
  module Configuration
    # OIDC の接続設定の正本。
    #
    # 3 つをまとめて扱う。1 つでも欠けた状態では認可を開始できず、
    # 欠けたまま起動させると、ログインを試みた利用者がその場で気付くことになる。
    #
    # 設定が 1 つも無い場合は「使わない」として扱う。内部認証で動かす環境では、
    # OIDC の設定は無い。
    module Oidc
      ISSUER_VARIABLE = "OIDC_ISSUER".freeze
      CLIENT_ID_VARIABLE = "OIDC_CLIENT_ID".freeze
      CLIENT_SECRET_VARIABLE = "OIDC_CLIENT_SECRET".freeze

      VARIABLES = [ ISSUER_VARIABLE, CLIENT_ID_VARIABLE, CLIENT_SECRET_VARIABLE ].freeze

      # 設定として受け付けられない値だった。
      class InvalidOidcSettings < ArgumentError; end

      Settings = Struct.new(:issuer, :client_id, :client_secret, keyword_init: true) do
        # 発見の経路。発行者の末尾へ足す形は仕様で決まっている。
        def discovery_url = "#{issuer}/.well-known/openid-configuration"
      end

      class << self
        # 実行環境から読む唯一の場所とする。
        def current = resolve(ENV)

        def configured? = !current.nil?

        def resolve(source)
          values = VARIABLES.index_with { |name| source[name].to_s }

          return nil if values.values.all?(&:empty?)

          missing = values.select { |_name, value| value.empty? }.keys
          raise InvalidOidcSettings, missing_message(missing) if missing.any?

          Settings.new(
            issuer: normalized_issuer(values.fetch(ISSUER_VARIABLE)),
            client_id: values.fetch(CLIENT_ID_VARIABLE),
            client_secret: values.fetch(CLIENT_SECRET_VARIABLE)
          )
        end

        private
          # 末尾の斜線だけを取り除く。それ以外は補正しない。
          #
          # 補正すると、設定に書いた値と、iss の照合に使う値が食い違う。
          # 斜線だけを扱うのは、同じ発行者が別の値として扱われるのを防ぐためで、
          # 発見の経路の組み立てでも斜線が二重になる。
          def normalized_issuer(raw)
            issuer = raw.chomp("/")
            uri = URI.parse(issuer)

            unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.query.nil? && uri.fragment.nil?
              raise InvalidOidcSettings, issuer_message(raw)
            end

            issuer
          rescue URI::InvalidURIError
            raise InvalidOidcSettings, issuer_message(raw)
          end

          def missing_message(missing)
            <<~TEXT.strip
              OIDC の設定が足りません: #{missing.join(", ")}
              #{VARIABLES.join("、")} の 3 つをすべて指定してください。
              1 つも指定しない場合は、OIDC を使わない状態として扱います。
            TEXT
          end

          def issuer_message(raw)
            <<~TEXT.strip
              #{ISSUER_VARIABLE}=#{raw.inspect} は受け入れられません。
              https で始まる発行者の URL を、問い合わせ文字列と断片なしで指定してください。
            TEXT
          end
      end
    end
  end
end
