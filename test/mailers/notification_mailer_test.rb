require "test_helper"

class NotificationMailerTest < ActionMailer::TestCase
  include Rails.application.routes.url_helpers
  test "宛先と件名が利用者の情報から組み立てられる" do
    notification = Notification.deliver(user: users(:taro), subject: announcements(:company_wide),
                                        event: "announcement_published")

    mail = NotificationMailer.with(notification: notification).notify

    assert_equal [ users(:taro).email_address ], mail.to
    assert_includes mail.subject, announcements(:company_wide).title
  end

  test "文面は受け取る利用者の表示言語で組み立てる" do
    notification = Notification.deliver(user: users(:hanako), subject: announcements(:company_wide),
                                        event: "announcement_published")

    mail = NotificationMailer.with(notification: notification).notify

    # hanako は表示言語を英語に設定している。
    assert_includes mail.subject, I18n.t("notifications.events.announcement_published",
                                         title: announcements(:company_wide).title, locale: :en)
    assert_includes mail.body.to_s, I18n.t("notification_mailer.notify.open", locale: :en)
  end

  test "本文に対象への経路が含まれる" do
    notification = Notification.deliver(user: users(:taro), subject: requests(:hanako_expense_pending),
                                        event: "request_submitted")

    mail = NotificationMailer.with(notification: notification).notify

    assert_includes mail.body.to_s, notification_url(notification, host: "example.com")
  end
end
