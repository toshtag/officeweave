require "test_helper"

class Officeweave::Configuration::OidcTest < ActiveSupport::TestCase
  SETTINGS = {
    "OIDC_ISSUER" => "https://idp.example.com",
    "OIDC_CLIENT_ID" => "officeweave",
    "OIDC_CLIENT_SECRET" => "a-client-secret"
  }.freeze

  test "3 つがそろっていれば解決できる" do
    settings = resolve(SETTINGS)

    assert_equal "https://idp.example.com", settings.issuer
    assert_equal "officeweave", settings.client_id
    assert_equal "a-client-secret", settings.client_secret
  end

  test "末尾の斜線は取り除く" do
    # 発見の経路と iss の照合で、同じ発行者が別の値として扱われる。
    settings = resolve(SETTINGS.merge("OIDC_ISSUER" => "https://idp.example.com/"))

    assert_equal "https://idp.example.com", settings.issuer
  end

  test "暗号化されていない発行者は受け付けない" do
    assert_invalid(SETTINGS.merge("OIDC_ISSUER" => "http://idp.example.com"), "OIDC_ISSUER")
  end

  test "発行者として読めない値は受け付けない" do
    assert_invalid(SETTINGS.merge("OIDC_ISSUER" => "idp.example.com"), "OIDC_ISSUER")
    assert_invalid(SETTINGS.merge("OIDC_ISSUER" => "https://"), "OIDC_ISSUER")
    assert_invalid(SETTINGS.merge("OIDC_ISSUER" => "https://idp.example.com?a=1"), "OIDC_ISSUER")
  end

  test "欠けている設定を名前で示す" do
    SETTINGS.each_key do |name|
      assert_invalid(SETTINGS.merge(name => nil), name)
      assert_invalid(SETTINGS.merge(name => ""), name)
    end
  end

  test "設定が 1 つも無ければ、使わない状態として扱う" do
    # 内部認証で動かす環境では、OIDC の設定は無い。
    assert_nil Officeweave::Configuration::Oidc.resolve({})
  end

  private
    def resolve(values)
      Officeweave::Configuration::Oidc.resolve(values)
    end

    def assert_invalid(values, expected_name)
      error = assert_raises(Officeweave::Configuration::Oidc::InvalidOidcSettings, values.inspect) do
        resolve(values)
      end

      assert_includes error.message, expected_name
    end
end
