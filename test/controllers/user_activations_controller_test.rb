require "test_helper"

class UserActivationsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:taro) }

  test "利用者を無効にできる" do
    delete user_activation_url(users(:hanako))

    assert_redirected_to users_path
    assert_not_predicate users(:hanako).reload, :active?
  end

  test "無効にするとセッションも終了する" do
    users(:hanako).sessions.create!

    assert_difference -> { Session.count }, -1 do
      delete user_activation_url(users(:hanako))
    end
  end

  test "無効にした利用者を再び有効にできる" do
    users(:hanako).deactivate!

    post user_activation_url(users(:hanako))

    assert_predicate users(:hanako).reload, :active?
  end

  test "自分自身は無効にできない" do
    delete user_activation_url(users(:taro))

    assert_predicate users(:taro).reload, :active?
    assert_equal I18n.t("users.cannot_deactivate_self"), flash[:alert]
  end

  test "一般利用者は無効化を実行できない" do
    sign_out
    sign_in_as users(:hanako)

    delete user_activation_url(users(:taro))

    assert_response :forbidden
    assert_predicate users(:taro).reload, :active?
  end
end
