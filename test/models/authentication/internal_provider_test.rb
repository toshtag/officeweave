require "test_helper"

module Authentication
  class InternalProviderTest < ActiveSupport::TestCase
    test "正しい資格情報で利用者を返す" do
      user = InternalProvider.authenticate(email_address: users(:taro).email_address,
                                           password: "password-for-tests")

      assert_equal users(:taro), user
    end

    test "誤ったパスワードでは nil を返す" do
      assert_nil InternalProvider.authenticate(email_address: users(:taro).email_address,
                                               password: "wrong-password")
    end

    test "存在しない利用者では nil を返す" do
      assert_nil InternalProvider.authenticate(email_address: "nobody@example.com", password: "x")
    end

    test "無効にされた利用者では nil を返す" do
      users(:hanako).deactivate!

      assert_nil InternalProvider.authenticate(email_address: users(:hanako).email_address,
                                               password: "password-for-tests")
    end

    test "パスワードの入力を求める" do
      assert_predicate InternalProvider, :password_required?
    end
  end
end
