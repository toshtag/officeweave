require "test_helper"

class AuthenticationProviderTest < ActionDispatch::IntegrationTest
  # パスワードを求めない外部方式の代わりとして使う。
  class PasswordlessProvider
    def self.name_key = "passwordless"
    def self.password_required? = false
    def self.authenticate(email_address:, password:) = User.find_by(email_address: email_address)
  end

  teardown do
    Authentication::ProviderRegistry.instance_variable_get(:@providers).delete("passwordless")
    ENV.delete("AUTHENTICATION_PROVIDER")
  end

  test "既定では内部認証でログインする" do
    post session_path, params: { email_address: users(:taro).email_address, password: "password-for-tests" }

    assert_redirected_to root_path
  end

  test "既定ではパスワードの入力欄が表示される" do
    get new_session_path

    assert_select "input[name=password]"
  end

  test "差し替えた方式でログインできる" do
    Authentication::ProviderRegistry.register(PasswordlessProvider)
    ENV["AUTHENTICATION_PROVIDER"] = "passwordless"

    post session_path, params: { email_address: users(:taro).email_address }

    assert_redirected_to root_path
  end

  test "差し替えた方式ではパスワードの入力欄を出さない" do
    Authentication::ProviderRegistry.register(PasswordlessProvider)
    ENV["AUTHENTICATION_PROVIDER"] = "passwordless"

    get new_session_path

    assert_select "input[name=password]", count: 0
  end

  test "差し替えた方式で認証できない場合は入れない" do
    Authentication::ProviderRegistry.register(PasswordlessProvider)
    ENV["AUTHENTICATION_PROVIDER"] = "passwordless"

    post session_path, params: { email_address: "nobody@example.com" }

    assert_redirected_to new_session_path
  end
end
