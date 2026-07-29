require "test_helper"

class NotificationPreferenceTest < ActiveSupport::TestCase
  test "設定していない種類は受け取る扱いになる" do
    assert users(:taro).mail_notifications_for?("announcement_published")
  end

  test "受け取らない設定にできる" do
    users(:taro).notification_preferences.create!(event: "announcement_published", mail_enabled: false)

    assert_not users(:taro).mail_notifications_for?("announcement_published")
  end

  test "設定は種類ごとに独立している" do
    users(:taro).notification_preferences.create!(event: "announcement_published", mail_enabled: false)

    assert users(:taro).mail_notifications_for?("request_approved")
  end

  test "同じ種類の設定を二重に持てない" do
    users(:taro).notification_preferences.create!(event: "announcement_published", mail_enabled: false)
    duplicate = users(:taro).notification_preferences.new(event: "announcement_published")

    assert_not duplicate.valid?
  end

  test "知らない種類は設定できない" do
    preference = users(:taro).notification_preferences.new(event: "unknown_event")

    assert_not preference.valid?
  end
end
