require "test_helper"

module Authentication
  class ProviderRegistryTest < ActiveSupport::TestCase
    # 差し替えの検証に使う、記録を持たない方式。
    class StubProvider
      def self.name_key = "stub"
      def self.password_required? = false
      def self.authenticate(email_address:, password:) = User.find_by(email_address: email_address)
    end

    teardown { ProviderRegistry.instance_variable_get(:@providers).delete("stub") }

    test "既定は内部認証になる" do
      assert_equal InternalProvider, ProviderRegistry.current
    end

    test "登録した方式を名前で取り出せる" do
      ProviderRegistry.register(StubProvider)

      assert_equal StubProvider, ProviderRegistry.fetch("stub")
      assert_includes ProviderRegistry.registered, "stub"
    end

    test "設定で方式を切り替えられる" do
      ProviderRegistry.register(StubProvider)

      with_provider("stub") do
        assert_equal StubProvider, ProviderRegistry.current
      end
    end

    test "知らない名前が指定された場合は内部認証へ落とす" do
      with_provider("does-not-exist") do
        assert_equal InternalProvider, ProviderRegistry.current
      end
    end

    test "知らない名前を直接取り出そうとすると失敗する" do
      assert_raises(ProviderRegistry::UnknownProvider) { ProviderRegistry.fetch("does-not-exist") }
    end

    private
      def with_provider(name)
        original = ENV["AUTHENTICATION_PROVIDER"]
        ENV["AUTHENTICATION_PROVIDER"] = name
        yield
      ensure
        ENV["AUTHENTICATION_PROVIDER"] = original
      end
  end
end
