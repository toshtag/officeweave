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

  test "配信設定の保存に失敗すると表示言語も変わらない" do
    with_failing_notification_preferences do
      patch settings_url, params: { user: { locale: "en" }, mail_notifications: [ "request_approved" ] }
    end

    user = users(:taro).reload

    assert_response :unprocessable_content
    assert_nil user.locale
    assert_empty user.notification_preferences
  end

  test "配信設定の保存に失敗した理由を画面へ示す" do
    with_failing_notification_preferences do
      patch settings_url, params: { user: { locale: "en" } }
    end

    reason = I18n.t("errors.messages.notification_preferences_not_saved")

    assert_select ".error-summary", text: /#{Regexp.escape(reason)}/
  end

  test "途中まで保存された配信設定は残らない" do
    users(:taro).notification_preferences.create!(event: "request_approved", mail_enabled: true)

    with_failing_notification_preferences(after: 1) do
      patch settings_url, params: { user: { locale: "" }, mail_notifications: [] }
    end

    user = users(:taro).reload

    assert_response :unprocessable_content
    assert_equal [ "request_approved" ], user.notification_preferences.pluck(:event)
    assert user.mail_notifications_for?("request_approved")
  end

  test "ログインしていない場合は開けない" do
    sign_out

    get settings_url

    assert_redirected_to new_session_path
  end

  private
    # 配信設定の保存だけを失敗させる。
    #
    # 画面から送れる値の中に、配信設定の検証で拒めるものがない。
    # 種類は画面が並べたものだけであり、有効・無効の 2 値しか受け取らない。
    # 保存の失敗そのものを作らないと、部分的に保存される経路へ届かない。
    #
    # 差し替えは検証の可否だけとし、保存の呼び方には触れない。
    # `after:` を渡すと、その件数を保存したあとから失敗する。
    def with_failing_notification_preferences(after: 0)
      remaining = after

      NotificationPreference.define_method(:valid?) do |*|
        next false unless remaining.positive?

        remaining -= 1
        true
      end

      yield
    ensure
      NotificationPreference.remove_method(:valid?)
    end
end
