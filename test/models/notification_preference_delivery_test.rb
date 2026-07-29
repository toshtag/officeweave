require "test_helper"

class NotificationPreferenceDeliveryTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  test "受け取らない設定の種類はメールを送らない" do
    users(:taro).notification_preferences.create!(event: "announcement_published", mail_enabled: false)

    assert_no_enqueued_emails do
      Notification.deliver(user: users(:taro), subject: announcements(:company_wide),
                           event: "announcement_published")
    end
  end

  test "受け取らない設定でも画面の通知は残る" do
    users(:taro).notification_preferences.create!(event: "announcement_published", mail_enabled: false)

    assert_difference -> { users(:taro).notifications.count }, 1 do
      Notification.deliver(user: users(:taro), subject: announcements(:company_wide),
                           event: "announcement_published")
    end
  end

  test "他の種類の通知は引き続きメールで届く" do
    users(:taro).notification_preferences.create!(event: "announcement_published", mail_enabled: false)

    assert_enqueued_emails 1 do
      Notification.deliver(user: users(:taro), subject: requests(:hanako_expense_pending),
                           event: "request_submitted")
    end
  end
end
