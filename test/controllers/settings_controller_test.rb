require "test_helper"

class SettingsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:taro) }

  test "自分の設定を開ける" do
    get settings_url

    assert_response :success
    assert_select "h1", I18n.t("settings.heading")
  end

  test "表示言語を変更できる" do
    patch settings_url, params: { user: { locale: "en" }, mail_notifications: Notification::EVENTS }

    assert_redirected_to settings_path
    assert_equal "en", users(:taro).reload.locale
  end

  test "受け取る通知を選べる" do
    patch settings_url, params: {
      user: { locale: "" }, mail_notifications: [ "request_approved" ]
    }

    user = users(:taro).reload

    assert user.mail_notifications_for?("request_approved")
    assert_not user.mail_notifications_for?("announcement_published")
  end

  test "何も選ばないとすべて受け取らない設定になる" do
    patch settings_url, params: { user: { locale: "" } }

    user = users(:taro).reload

    assert Notification::EVENTS.none? { |event| user.mail_notifications_for?(event) }
  end

  test "対応していない表示言語は保存できない" do
    patch settings_url, params: { user: { locale: "fr" } }

    assert_response :unprocessable_content
  end

  test "ログインしていない場合は開けない" do
    sign_out

    get settings_url

    assert_redirected_to new_session_path
  end
end
