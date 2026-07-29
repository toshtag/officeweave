require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:taro) }

  test "ログイン画面は認証なしで表示できる" do
    get new_session_path

    assert_response :success
  end

  test "正しい資格情報でログインできる" do
    post session_path, params: { email_address: @user.email_address, password: "password-for-tests" }

    assert_redirected_to root_path
    assert cookies[:session_id].present?
  end

  test "大文字と前後の空白の違いを吸収してログインできる" do
    post session_path, params: { email_address: "  TARO@Example.com  ", password: "password-for-tests" }

    assert_redirected_to root_path
  end

  test "誤ったパスワードではログインできない" do
    post session_path, params: { email_address: @user.email_address, password: "wrong-password" }

    assert_redirected_to new_session_path
    assert cookies[:session_id].blank?
  end

  test "存在しない利用者と誤ったパスワードで応答が変わらない" do
    post session_path, params: { email_address: "nobody@example.com", password: "wrong-password" }
    missing_user_flash = flash[:alert]

    post session_path, params: { email_address: @user.email_address, password: "wrong-password" }

    assert_equal missing_user_flash, flash[:alert]
  end

  test "ログアウトするとセッションが破棄される" do
    sign_in_as(@user)

    assert_difference -> { Session.count }, -1 do
      delete session_path
    end

    assert_redirected_to new_session_path
  end

  test "ログインしていない場合は保護された画面から追い返される" do
    get root_url

    assert_redirected_to new_session_path
  end

  test "ログイン後は元の画面へ戻る" do
    get root_url
    assert_redirected_to new_session_path

    post session_path, params: { email_address: @user.email_address, password: "password-for-tests" }

    assert_redirected_to root_url
  end
end
