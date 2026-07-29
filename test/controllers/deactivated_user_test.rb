require "test_helper"

class DeactivatedUserTest < ActionDispatch::IntegrationTest
  test "無効にされた利用者はログインできない" do
    users(:hanako).deactivate!

    post session_path, params: { email_address: users(:hanako).email_address, password: "password-for-tests" }

    assert_redirected_to new_session_path
    assert_equal I18n.t("sessions.failed"), flash[:alert]
  end

  test "無効にされた理由を、失敗の応答から区別できない" do
    users(:hanako).deactivate!

    post session_path, params: { email_address: users(:hanako).email_address, password: "password-for-tests" }
    deactivated_flash = flash[:alert]

    post session_path, params: { email_address: users(:taro).email_address, password: "wrong-password" }

    assert_equal deactivated_flash, flash[:alert]
  end

  test "利用中に無効化されると、以降の要求は認証済みとして扱われない" do
    sign_in_as users(:hanako)
    get root_url
    assert_response :success

    users(:hanako).update!(deactivated_at: Time.current)

    get root_url

    assert_redirected_to new_session_path
  end
end
