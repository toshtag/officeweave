require "test_helper"

class PasswordChangeTest < ActionDispatch::IntegrationTest
  test "パスワードが変わると、変更前の Cookie では認証されない" do
    sign_in_as users(:hanako)
    get root_url
    assert_response :success

    users(:hanako).update!(password: "a-new-long-secret-value",
                           password_confirmation: "a-new-long-secret-value")

    get root_url

    assert_redirected_to new_session_path
  end

  test "管理者がパスワードを変更すると、その利用者のセッションが終わる" do
    session = users(:hanako).sessions.create!
    sign_in_as users(:taro)

    patch user_url(users(:hanako)), params: {
      user: { name: users(:hanako).name, email_address: users(:hanako).email_address,
              password: "a-new-long-secret-value", password_confirmation: "a-new-long-secret-value" }
    }

    assert_redirected_to users_path
    assert_not Session.exists?(session.id)
  end

  test "パスワードを伴わない更新では、その利用者のセッションが残る" do
    session = users(:hanako).sessions.create!
    sign_in_as users(:taro)

    patch user_url(users(:hanako)), params: {
      user: { name: "佐藤 花子（更新）", email_address: users(:hanako).email_address,
              password: "", password_confirmation: "" }
    }

    assert_redirected_to users_path
    assert Session.exists?(session.id)
  end

  test "パスワードを変更した利用者は、新しいパスワードでログインし直せる" do
    users(:hanako).update!(password: "a-new-long-secret-value",
                           password_confirmation: "a-new-long-secret-value")

    post session_path, params: { email_address: users(:hanako).email_address,
                                 password: "a-new-long-secret-value" }

    assert_redirected_to root_path
  end
end
