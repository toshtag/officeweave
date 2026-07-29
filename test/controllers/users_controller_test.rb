require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:taro) }

  test "自組織の利用者だけが一覧に並ぶ" do
    get users_url

    assert_response :success
    assert_select "td", text: users(:hanako).email_address
    assert_select "td", text: users(:outsider).email_address, count: 0
  end

  test "利用者を追加できる" do
    assert_difference -> { User.count }, 1 do
      post users_url, params: {
        user: { name: "鈴木 一郎", email_address: "ichiro@example.com",
                password: "a-secret-value", password_confirmation: "a-secret-value", role: "member" }
      }
    end

    assert_redirected_to users_path
    assert_equal organizations(:main), User.find_by(email_address: "ichiro@example.com").organization
  end

  test "パスワードの確認が一致しないと追加できない" do
    assert_no_difference -> { User.count } do
      post users_url, params: {
        user: { name: "鈴木 一郎", email_address: "ichiro@example.com",
                password: "a-secret-value", password_confirmation: "different-value" }
      }
    end

    assert_response :unprocessable_content
  end

  test "パスワードを空にすると変更されない" do
    user = users(:hanako)
    digest_before = user.password_digest

    patch user_url(user), params: { user: { name: "佐藤 花子", password: "", password_confirmation: "" } }

    assert_redirected_to users_path
    assert_equal digest_before, user.reload.password_digest
  end

  test "パスワードを指定すると変更される" do
    user = users(:hanako)
    digest_before = user.password_digest

    patch user_url(user), params: {
      user: { password: "a-new-secret-value", password_confirmation: "a-new-secret-value" }
    }

    assert_not_equal digest_before, user.reload.password_digest
  end

  test "権限を変更できる" do
    patch user_url(users(:hanako)), params: { user: { role: "administrator" } }

    assert_predicate users(:hanako).reload, :administrator?
  end

  test "別組織の利用者は編集できない" do
    get edit_user_url(users(:outsider))

    assert_response :not_found
  end

  test "一般利用者は利用者管理へ入れない" do
    sign_out
    sign_in_as users(:hanako)

    get users_url

    assert_response :forbidden
  end
end
