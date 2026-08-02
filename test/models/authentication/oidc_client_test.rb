require "test_helper"
require_relative "../../test_helpers/local_http_server_test_helper"
require_relative "../../test_helpers/local_certificate_test_helper"
require_relative "../../test_helpers/oidc_provider_test_helper"

module Authentication
  # 認可サーバーとの通信。
  #
  # 相手の応答をどこまで信じるかを、ここで決める。実際の TLS と実際の HTTP で
  # 確かめる。差し替えた偽物では、暗号化の要求、転送の追従、上限の扱いを
  # 確かめられない。
  class OidcClientTest < ActiveSupport::TestCase
    include LocalHttpServerTestHelper
    include OidcProviderTestHelper

    # 並列実行では、他の worker が同じ 443 番を使う。
    self.use_transactional_tests = false

    test "発見の経路から端点と鍵を読む" do
      with_oidc_provider do |provider|
        client = build(provider)

        assert_equal "#{provider.issuer}/authorize", client.authorization_endpoint
        assert_equal "#{provider.issuer}/token", client.token_endpoint
        assert_equal KEY_ID, client.jwks.fetch("keys").first["kid"]
      end
    end

    test "発見の経路は決まった場所から読む" do
      with_oidc_provider do |provider|
        build(provider).authorization_endpoint

        assert_equal "/.well-known/openid-configuration", provider.path_of(0)
      end
    end

    test "名乗る発行者が設定と違えば受け付けない" do
      responses = { "/.well-known/openid-configuration" => { issuer: "https://attacker.example.com" } }

      with_oidc_provider(responses) do |provider|
        assert_raises(Oidc::Client::ProviderError) { build(provider).authorization_endpoint }
      end
    end

    test "端点が暗号化されていなければ受け付けない" do
      # 認可の宛先も token の宛先も、発見の応答が決める。
      responses = {
        "/.well-known/openid-configuration" => {
          issuer: "https://#{OidcProviderTestHelper::ISSUER_HOSTNAME}",
          authorization_endpoint: "http://#{OidcProviderTestHelper::ISSUER_HOSTNAME}/authorize",
          token_endpoint: "https://#{OidcProviderTestHelper::ISSUER_HOSTNAME}/token",
          jwks_uri: "https://#{OidcProviderTestHelper::ISSUER_HOSTNAME}/jwks"
        }
      }

      with_oidc_provider(responses) do |provider|
        assert_raises(Oidc::Client::ProviderError) { build(provider).authorization_endpoint }
      end
    end

    test "端点が別の発行者を指していれば受け付けない" do
      responses = {
        "/.well-known/openid-configuration" => {
          issuer: "https://#{OidcProviderTestHelper::ISSUER_HOSTNAME}",
          authorization_endpoint: "https://attacker.example.com/authorize",
          token_endpoint: "https://#{OidcProviderTestHelper::ISSUER_HOSTNAME}/token",
          jwks_uri: "https://#{OidcProviderTestHelper::ISSUER_HOSTNAME}/jwks"
        }
      }

      with_oidc_provider(responses) do |provider|
        assert_raises(Oidc::Client::ProviderError) { build(provider).authorization_endpoint }
      end
    end

    test "端点が欠けていれば受け付けない" do
      responses = { "/.well-known/openid-configuration" => { issuer: "https://#{OidcProviderTestHelper::ISSUER_HOSTNAME}" } }

      with_oidc_provider(responses) do |provider|
        assert_raises(Oidc::Client::ProviderError) { build(provider).token_endpoint }
      end
    end

    test "発見と鍵の取得は一度で済ませる" do
      with_oidc_provider do |provider|
        client = build(provider)
        3.times { client.authorization_endpoint }
        3.times { client.jwks }

        # ログインのたびに 2 往復増えると、認可サーバーへの負荷が利用回数に比例する。
        assert_equal [ "/.well-known/openid-configuration", "/jwks" ], provider.requests.call.map { _1[:path] }
      end
    end

    test "認可の宛先へ必要な指定を並べる" do
      with_oidc_provider do |provider|
        url = build(provider).authorization_url(
          redirect_uri: "https://officeweave.example.com/oidc/callback",
          state: "a-state", nonce: "a-nonce", code_challenge: "a-challenge"
        )
        query = URI.decode_www_form(URI.parse(url).query).to_h

        assert_equal "#{provider.issuer}/authorize", url.split("?").first
        assert_equal "code", query["response_type"]
        assert_equal "officeweave", query["client_id"]
        assert_equal "openid email", query["scope"]
        assert_equal "a-state", query["state"]
        assert_equal "a-nonce", query["nonce"]
        assert_equal "a-challenge", query["code_challenge"]
        assert_equal "S256", query["code_challenge_method"]
      end
    end

    test "code を id_token へ交換する" do
      expected = OidcProviderTestHelper.id_token

      with_oidc_provider("/token" => { id_token: expected }) do |provider|
        assert_equal expected, exchange(provider)
        assert_equal "/token", provider.path_of(1)
      end
    end

    test "交換では client_secret を本文へ入れない" do
      with_oidc_provider(token_response) do |provider|
        exchange(provider)

        # 経路の記録へ残りやすい場所へ秘密を置かない。
        refute_includes provider.body_of(1).to_s, "a-client-secret"
        assert_includes provider.header_of(1, "authorization").to_s, "Basic "
      end
    end

    test "交換では code と検証用の値を送る" do
      with_oidc_provider(token_response) do |provider|
        exchange(provider)
        body = URI.decode_www_form(provider.body_of(1)).to_h

        assert_equal "authorization_code", body["grant_type"]
        assert_equal "a-code", body["code"]
        assert_equal "a-verifier", body["code_verifier"]
        assert_equal "https://officeweave.example.com/oidc/callback", body["redirect_uri"]
      end
    end

    test "交換が失敗すれば理由を伏せて失敗として返す" do
      responses = { "/token" => [ 400, { error: "invalid_grant" } ] }

      with_oidc_provider(responses) do |provider|
        error = assert_raises(Oidc::Client::ProviderError) { exchange(provider) }

        refute_includes error.message, "a-code"
      end
    end

    test "交換の応答に id_token が無ければ失敗として返す" do
      responses = { "/token" => { access_token: "only-access-token" } }

      with_oidc_provider(responses) do |provider|
        assert_raises(Oidc::Client::ProviderError) { exchange(provider) }
      end
    end

    test "信頼できない証明書の相手とは通信しない" do
      with_oidc_provider({}, tls: LocalCertificateTestHelper.untrusted) do |provider|
        assert_raises(Oidc::Client::ProviderError) { build(provider).authorization_endpoint }
      end
    end

    test "大きすぎる応答は読み切らない" do
      responses = { "/jwks" => [ 200, "x" * (Oidc::Client::RESPONSE_LIMIT + 1) ] }

      with_oidc_provider(responses) do |provider|
        assert_raises(Oidc::Client::ProviderError) { build(provider).jwks }
      end
    end

    private
      def token_response
        { "/token" => { id_token: OidcProviderTestHelper.id_token } }
      end

      def build(provider)
        settings = Officeweave::Configuration::Oidc::Settings.new(
          issuer: provider.issuer, client_id: "officeweave", client_secret: "a-client-secret"
        )

        Oidc::Client.new(settings).tap do |client|
          client.certificate_store = LocalCertificateTestHelper.trusted.store
          client.resolver = oidc_resolver
        end
      end

      def exchange(provider)
        build(provider).exchange_code(
          code: "a-code", redirect_uri: "https://officeweave.example.com/oidc/callback",
          code_verifier: "a-verifier"
        )
      end
  end
end
