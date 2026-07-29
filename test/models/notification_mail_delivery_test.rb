require "test_helper"

class NotificationMailDeliveryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  test "通知を作るとメールの送信が積まれる" do
    assert_enqueued_emails 1 do
      Notification.deliver(user: users(:taro), subject: announcements(:company_wide),
                           event: "announcement_published")
    end
  end

  test "二重の通知ではメールも積まれない" do
    Notification.deliver(user: users(:taro), subject: announcements(:company_wide),
                         event: "announcement_published")

    assert_no_enqueued_emails do
      Notification.deliver(user: users(:taro), subject: announcements(:company_wide),
                           event: "announcement_published")
    end
  end

  test "無効にされた利用者へはメールも送らない" do
    users(:hanako).deactivate!

    assert_no_enqueued_emails do
      Notification.deliver(user: users(:hanako), subject: announcements(:company_wide),
                           event: "announcement_published")
    end
  end

  test "積まれた送信を実行するとメールが届く" do
    Notification.deliver(user: users(:taro), subject: announcements(:company_wide),
                         event: "announcement_published")

    assert_difference -> { ActionMailer::Base.deliveries.size }, 1 do
      perform_enqueued_jobs
    end
  end
end
