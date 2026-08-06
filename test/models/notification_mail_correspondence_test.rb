require "test_helper"

# 画面へ出す通知と、メールの送信の対応。
#
# 画面には出るのにメールが来ない、あるいはその逆は、利用者から見ると
# どちらも「通知が壊れている」ように映る。対応そのものをここで固定する。
#
# 送信の控えは持たない。持てば、控えと実際の送信という 2 つの記録を
# 一致させ続ける必要が生まれる。対応は、通知 1 件につきメール 1 通という
# 積み方で保つ。
class NotificationMailCorrespondenceTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  setup do
    @request = requests(:taro_leave_pending)
    @user = users(:approver)
    Notification.where(subject: @request).delete_all
  end

  test "画面の通知 1 件につき、メールを 1 通だけ積む" do
    assert_enqueued_emails 1 do
      deliver(occurrence: "activity:1")
    end
  end

  test "同じ発生を二度呼んでも、メールは増えない" do
    deliver(occurrence: "activity:1")

    assert_no_enqueued_emails do
      deliver(occurrence: "activity:1")
    end
  end

  test "発生が違えば、メールも改めて積む" do
    deliver(occurrence: "activity:1")

    assert_enqueued_emails 1 do
      deliver(occurrence: "activity:2")
    end
  end

  test "メールを受け取らない設定では、画面の通知だけを残す" do
    @user.notification_preferences.create!(event: "request_submitted", mail_enabled: false)

    assert_no_enqueued_emails do
      assert_not_nil deliver(occurrence: "activity:1")
    end

    assert_equal 1, Notification.where(subject: @request, user: @user).count
  end

  test "まとめて作る経路でも、作られた件数だけ送る" do
    other = users(:hanako)

    assert_enqueued_jobs 1, only: NotificationMailFanoutJob do
      Notification.deliver_to_all(users: [ @user, other ], subject: @request,
                                  event: "request_submitted", occurrence: "activity:1")
    end

    assert_enqueued_emails 2 do
      perform_enqueued_jobs(only: NotificationMailFanoutJob)
    end
  end

  test "まとめて作る経路で 1 件も作られなければ、送信も積まない" do
    Notification.deliver_to_all(users: [ @user ], subject: @request,
                                event: "request_submitted", occurrence: "activity:1")

    assert_no_enqueued_jobs only: NotificationMailFanoutJob do
      Notification.deliver_to_all(users: [ @user ], subject: @request,
                                  event: "request_submitted", occurrence: "activity:1")
    end
  end

  test "無効にされた利用者へは、画面の通知もメールも作らない" do
    @user.update!(deactivated_at: Time.current)

    assert_no_enqueued_emails do
      assert_nil deliver(occurrence: "activity:1")
    end
  end

  private
    def deliver(occurrence:)
      Notification.deliver(user: @user, subject: @request, event: "request_submitted",
                           occurrence: occurrence)
    end
end
