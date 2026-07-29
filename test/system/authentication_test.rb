require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  test "JavaScript なしでログインとログアウトができる" do
    visit root_path

    assert_current_path new_session_path

    sign_in_as users(:taro)

    assert_current_path root_path
    assert_text users(:taro).name

    click_button I18n.t("sessions.sign_out")

    assert_current_path new_session_path
  end

  test "誤ったパスワードでは入れず、理由を区別して伝えない" do
    visit new_session_path
    fill_in "email_address", with: users(:taro).email_address
    fill_in "password", with: "wrong-password"
    click_button I18n.t("sessions.new.submit")

    assert_current_path new_session_path
    assert_text I18n.t("sessions.failed")
  end

  test "ログインしていない場合は言語の切り替えだけ使える" do
    visit new_session_path

    click_button "English"

    assert_text I18n.t("sessions.new.heading", locale: :en)
  end

  test "利用者に設定された言語が表示に使われる" do
    sign_in_as users(:hanako)

    assert_text I18n.t("home.heading", locale: :en)
  end

  test "ログアウト後は保護された画面へ戻れない" do
    sign_in_as users(:taro)
    click_button I18n.t("sessions.sign_out")

    visit root_path

    assert_current_path new_session_path
  end
end
