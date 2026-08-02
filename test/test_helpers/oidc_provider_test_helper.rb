require "socket"
require "json"
require "jwt"

# その場限りの認可サーバー。
#
# 実際の TLS と実際の HTTP で、発見、鍵の取得、token の交換を確かめる。
# 相手の応答をどこまで信じるかを決める部分であり、差し替えた偽物では
# 通信そのものの扱い（暗号化の要求、転送の追従、上限）を確かめられない。
#
# 経路ごとに応答を決められるようにする。1 つの応答しか返せない足場では、
# 3 つの経路を通る流れを再現できない。
module OidcProviderTestHelper
  ISSUER_HOSTNAME = LocalCertificateTestHelper::HOSTNAME
  KEY_ID = "test-key".freeze

  Provider = Struct.new(:issuer, :key, :requests, keyword_init: true) do
    def jwks = { "keys" => [ JWT::JWK.new(key, kid: KEY_ID).export ] }

    def path_of(index) = requests.call[index][:path]
    def body_of(index) = requests.call[index][:body]
    def header_of(index, name) = requests.call[index][:headers][name]
  end

  # 鍵の生成は重いため、1 度だけ作って使い回す。
  def self.key
    @key ||= OpenSSL::PKey::RSA.generate(2048)
  end

  def self.issuer = "https://#{ISSUER_HOSTNAME}"

  # 応答として並べるために、サーバーを立てる前から組み立てられるようにする。
  def self.id_token(claims = {})
    payload = {
      iss: issuer, aud: "officeweave", sub: "subject-1",
      exp: 5.minutes.from_now.to_i, iat: Time.current.to_i,
      email: "person@example.com", email_verified: true
    }.merge(claims).compact

    JWT.encode(payload, key, "RS256", kid: KEY_ID)
  end

  # 認可サーバーを立て、経路ごとの応答を返す。
  #
  # responses は経路から応答への対応とする。値は次のいずれかとする。
  #
  #   Hash    JSON として返す（200）
  #   Array   [ ステータス, 本文 ] をそのまま返す
  #
  # 待ち受けは 443 とする。この製品は暗号化されていない発行者を受け付けない。
  def with_oidc_provider(responses = {}, tls: LocalCertificateTestHelper.trusted)
    address = loopback_address(3)
    issuer = "https://#{ISSUER_HOSTNAME}"
    received = []
    lock = Mutex.new
    plan = default_responses(issuer).merge(responses)

    server = build_tls_server(address, 443, tls)

    acceptor = Thread.new do
      loop do
        socket = begin
          server.accept
        rescue OpenSSL::SSL::SSLError, Errno::ECONNRESET
          next
        end

        request = read_request(socket)
        lock.synchronize { received << request }
        write_response(socket, plan[request[:path]] || [ 404, { error: "not_found" } ])
        socket.close
      rescue Errno::EPIPE, Errno::ECONNRESET, IOError
        nil
      end
    rescue IOError, Errno::EBADF, Errno::EINVAL
      nil
    end

    yield Provider.new(issuer: issuer, key: OidcProviderTestHelper.key,
                       requests: -> { lock.synchronize { received.dup } })
  ensure
    acceptor&.kill
    server&.close
  end

  # 認可サーバーの名前を、その接続だけで解決する。
  #
  # 実行環境の名前解決へは触らない。触ると、同じプロセスの他の通信まで
  # この対応を使う。
  def oidc_resolver(address = loopback_address(3))
    ->(_hostname) { address }
  end

  private
    def default_responses(issuer)
      {
        "/.well-known/openid-configuration" => {
          issuer: issuer,
          authorization_endpoint: "#{issuer}/authorize",
          token_endpoint: "#{issuer}/token",
          jwks_uri: "#{issuer}/jwks",
          response_types_supported: [ "code" ],
          id_token_signing_alg_values_supported: [ "RS256" ]
        },
        "/jwks" => { keys: [ JWT::JWK.new(OidcProviderTestHelper.key, kid: KEY_ID).export ] }
      }
    end

    def build_tls_server(address, port, tls)
      context = OpenSSL::SSL::SSLContext.new
      context.cert = tls.certificate
      context.key = tls.key

      OpenSSL::SSL::SSLServer.new(TCPServer.new(address, port), context)
    end

    def read_request(socket)
      request_line = socket.gets.to_s.strip
      headers = {}

      while (line = socket.gets)
        break if line == "\r\n" || line == "\n"

        name, value = line.split(":", 2)
        headers[name.to_s.strip.downcase] = value.to_s.strip
      end

      length = headers["content-length"].to_i
      body = length.positive? ? socket.read(length) : nil

      { path: request_line.split(" ")[1].to_s.split("?").first, method: request_line.split(" ").first,
        headers: headers, body: body }
    end

    def write_response(socket, response)
      status, payload = response.is_a?(Array) ? response : [ 200, response ]
      body = payload.is_a?(String) ? payload : payload.to_json

      socket.write("HTTP/1.1 #{status} OK\r\n")
      socket.write("Content-Type: application/json\r\n")
      socket.write("Content-Length: #{body.bytesize}\r\n\r\n")
      socket.write(body)
    end
end
