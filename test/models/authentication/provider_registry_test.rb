require "test_helper"

module Authentication
  class ProviderRegistryTest < ActiveSupport::TestCase
    # 差し替えの検証に使う、記録を持たない方式。
    class StubProvider
      def self.name_key = "stub"
      def self.password_required? = false
      def self.authenticate(email_address:, password:) = User.find_by(email_address: email_address)
    end

    # 登録側の不備を再現する、識別子だけが不正な方式。
    # 登録の時点で拒否されるため、他の呼び出しは持たない。
    class EmptyNameProvider
      def self.name_key = ""
    end

    class BlankNameProvider
      def self.name_key = " "
    end

    class PaddedNameProvider
      def self.name_key = " internal "
    end

    # 既に使われている識別子を、別の実装が名乗る場合を再現する。
    class ConflictingInternalProvider
      def self.name_key = "internal"
      def self.password_required? = false
      def self.authenticate(email_address:, password:) = nil
    end

    class ConflictingStubProvider
      def self.name_key = "stub"
      def self.password_required? = true
      def self.authenticate(email_address:, password:) = nil
    end

    # テスト用の登録を残さない。
    # 上書きを試す検査があるため、internal は既定へ必ず戻す。
    teardown do
      providers = ProviderRegistry.instance_variable_get(:@providers)
      providers.delete("stub")
      providers.delete("reloadable")
      providers["internal"] = InternalProvider
    end

    test "設定が無い場合は内部認証になる" do
      with_provider(nil) do
        assert_equal InternalProvider, ProviderRegistry.current
      end
    end

    test "内部認証を明示できる" do
      with_provider("internal") do
        assert_equal InternalProvider, ProviderRegistry.current
      end
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

    test "知らない名前が指定された場合は失敗する" do
      error = assert_raises(ProviderRegistry::UnknownProvider) do
        with_provider("does-not-exist") { ProviderRegistry.current }
      end

      assert_includes error.message, "AUTHENTICATION_PROVIDER"
      assert_includes error.message, "does-not-exist"
      assert_includes error.message, "internal"
    end

    test "空文字が指定された場合は失敗する" do
      error = assert_raises(ProviderRegistry::UnknownProvider) do
        with_provider("") { ProviderRegistry.current }
      end

      # 空文字は、そのままでは表示から消える。指定された値として読めるようにする。
      assert_includes error.message, %(AUTHENTICATION_PROVIDER="")
    end

    test "前後の空白を取り除かない" do
      assert_raises(ProviderRegistry::UnknownProvider) do
        with_provider(" internal ") { ProviderRegistry.current }
      end

      assert_raises(ProviderRegistry::UnknownProvider) do
        with_provider(" ") { ProviderRegistry.current }
      end
    end

    test "知らない名前を直接取り出そうとすると失敗する" do
      assert_raises(ProviderRegistry::UnknownProvider) { ProviderRegistry.fetch("does-not-exist") }
    end

    test "空文字の識別子は登録できない" do
      error = assert_raises(ProviderRegistry::InvalidProviderName) do
        ProviderRegistry.register(EmptyNameProvider)
      end

      assert_includes error.message, %(name_key="")
      assert_not_includes ProviderRegistry.registered, ""
    end

    test "空白だけの識別子は登録できない" do
      error = assert_raises(ProviderRegistry::InvalidProviderName) do
        ProviderRegistry.register(BlankNameProvider)
      end

      assert_includes error.message, %(name_key=" ")
      assert_not_includes ProviderRegistry.registered, " "
    end

    test "前後に空白を含む識別子は登録できない" do
      error = assert_raises(ProviderRegistry::InvalidProviderName) do
        ProviderRegistry.register(PaddedNameProvider)
      end

      assert_includes error.message, %(name_key=" internal ")
      assert_not_includes ProviderRegistry.registered, " internal "
      # 取り除いて登録し直さない。既存の internal も奪わせない。
      assert_equal InternalProvider, ProviderRegistry.fetch("internal")
    end

    test "別の実装は internal を名乗れない" do
      error = assert_raises(ProviderRegistry::DuplicateProviderName) do
        ProviderRegistry.register(ConflictingInternalProvider)
      end

      assert_includes error.message, "internal"
      assert_includes error.message, InternalProvider.name
      assert_includes error.message, ConflictingInternalProvider.name

      assert_equal InternalProvider, ProviderRegistry.fetch("internal")
      with_provider(nil) do
        assert_equal InternalProvider, ProviderRegistry.current
      end
    end

    test "別の実装は登録済みの識別子を上書きできない" do
      ProviderRegistry.register(StubProvider)
      before = ProviderRegistry.registered.dup

      assert_raises(ProviderRegistry::DuplicateProviderName) do
        ProviderRegistry.register(ConflictingStubProvider)
      end

      assert_equal StubProvider, ProviderRegistry.fetch("stub")
      assert_equal before, ProviderRegistry.registered
    end

    test "同じ実装の再登録は成功する" do
      ProviderRegistry.register(StubProvider)
      ProviderRegistry.register(StubProvider)

      assert_equal StubProvider, ProviderRegistry.fetch("stub")
      assert_equal 1, ProviderRegistry.registered.count("stub")
    end

    test "再読み込み後の同じ実装へ入れ替えられる" do
      # 開発環境では、同じ定数が再読み込みで別のクラスになる。
      # これを衝突として拒否すると、画面を開くたびに起動できなくなる。
      original = define_reloadable_provider
      ProviderRegistry.register(original)

      replacement = define_reloadable_provider
      ProviderRegistry.register(replacement)

      assert_not_same original, replacement
      assert_same replacement, ProviderRegistry.fetch("reloadable")
    ensure
      remove_reloadable_provider
    end

    private
      RELOADABLE = :ReloadableProvider

      # 同じ完全修飾名を持つ、別のクラスオブジェクトを作る。
      def define_reloadable_provider
        remove_reloadable_provider
        provider = Class.new do
          def self.name_key = "reloadable"
        end
        self.class.const_set(RELOADABLE, provider)
        provider
      end

      def remove_reloadable_provider
        self.class.send(:remove_const, RELOADABLE) if self.class.const_defined?(RELOADABLE, false)
      end

      # 親プロセスの設定へ依存させない。nil は「設定が無い」を意味する。
      def with_provider(name)
        original = ENV["AUTHENTICATION_PROVIDER"]
        assign_provider(name)
        yield
      ensure
        assign_provider(original)
      end

      def assign_provider(name)
        if name.nil?
          ENV.delete("AUTHENTICATION_PROVIDER")
        else
          ENV["AUTHENTICATION_PROVIDER"] = name
        end
      end
  end
end
