# パスワードを扱わない外部の認証方式の代わり。
#
# 資格情報がこの製品の中に無い状態を作る。パスワードに関わる経路が、
# その状態で何を返すかを確かめるために使う。
module PasswordlessProviderTestHelper
  class PasswordlessProvider
    def self.name_key = "passwordless"
    def self.password_required? = false
    def self.authenticate(email_address:, password:) = User.find_by(email_address: email_address)
  end

  private
    # 登録と設定を戻すところまでを 1 か所に置く。戻し忘れると、
    # 後続のテストがパスワードを使わない方式のまま走る。
    def with_passwordless_provider
      Authentication::ProviderRegistry.register(PasswordlessProvider)
      ENV["AUTHENTICATION_PROVIDER"] = PasswordlessProvider.name_key

      yield
    ensure
      Authentication::ProviderRegistry.instance_variable_get(:@providers)
                                      .delete(PasswordlessProvider.name_key)
      ENV.delete("AUTHENTICATION_PROVIDER")
    end
end
