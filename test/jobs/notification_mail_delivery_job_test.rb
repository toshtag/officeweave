require "test_helper"

# メール送信のやり直しの契約を固定する。
#
# 一時的な失敗をやり直さないと、送信サーバーの短い不調でメールが失われる。
# 恒久的な失敗をやり直すと、通らない送信を繰り返して他のジョブを詰まらせる。
class NotificationMailDeliveryJobTest < ActiveJob::TestCase
  # 送信を必ず失敗させる送信方式。このテストの中だけで使う。
  class FailingDeliveryMethod
    class << self
      attr_accessor :exception
    end

    def initialize(_settings = nil); end

    def deliver!(_mail)
      raise self.class.exception
    end
  end

  test "メールの送信はこのジョブが担う" do
    assert_equal "NotificationMailDeliveryJob", ActionMailer::Base.delivery_job.to_s
  end

  test "投入はトランザクションの確定後に行う" do
    assert NotificationMailDeliveryJob.enqueue_after_transaction_commit
  end

  test "合計 5 回まで実行する" do
    assert_equal 5, NotificationMailDeliveryJob::MAXIMUM_ATTEMPTS
    # 初回に加えたやり直しの回数。
    assert_equal 4, NotificationMailDeliveryJob::RETRY_INTERVALS.size
  end

  test "やり直しの待ち時間が短い順に伸びる" do
    assert_equal [ 5.seconds, 30.seconds, 2.minutes, 5.minutes ],
                 NotificationMailDeliveryJob::RETRY_INTERVALS

    assert_equal 5.seconds, NotificationMailDeliveryJob.interval_for(1)
    assert_equal 30.seconds, NotificationMailDeliveryJob.interval_for(2)
    assert_equal 2.minutes, NotificationMailDeliveryJob.interval_for(3)
    assert_equal 5.minutes, NotificationMailDeliveryJob.interval_for(4)
    # 上限を超えた場合も最後の値を使う。待ち時間が nil になると例外で落ちる。
    assert_equal 5.minutes, NotificationMailDeliveryJob.interval_for(9)
  end

  test "一時的な失敗と恒久的な失敗を重ねて分類しない" do
    NotificationMailDeliveryJob::PERMANENT_ERRORS.each do |permanent|
      NotificationMailDeliveryJob::TRANSIENT_ERRORS.each do |transient|
        refute permanent <= transient,
               "#{permanent} が #{transient} の一種として、やり直しの対象になっている"
      end
    end
  end

  test "一時的な失敗ではやり直しが積まれる" do
    [
      Net::SMTPServerBusy.new("450 busy"),
      Errno::ECONNREFUSED.new,
      Net::ReadTimeout.new,
      OpenSSL::SSL::SSLError.new("一時的な失敗")
    ].each do |exception|
      enqueue_notification_mail

      with_failing_delivery(exception) do
        perform_enqueued_jobs(only: NotificationMailDeliveryJob)
      end

      # やり直しは待ち時間の後に実行されるため、この時点では積まれたまま残る。
      assert_equal 1, enqueued_jobs.size, "#{exception.class} でやり直しが積まれていない"
      clear_enqueued_jobs
    end
  end

  test "恒久的な失敗ではやり直しを積まない" do
    NotificationMailDeliveryJob::PERMANENT_ERRORS.each do |error|
      enqueue_notification_mail

      with_failing_delivery(error.new("535 拒否")) do
        assert_raises(error, "#{error} が失敗として残らない") do
          perform_enqueued_jobs(only: NotificationMailDeliveryJob)
        end
      end

      assert_equal 0, enqueued_jobs.size, "#{error} でやり直しを積んでいる"
      clear_enqueued_jobs
    end
  end

  private
    def enqueue_notification_mail
      Notification.deliver(
        user: users(:hanako),
        subject: announcements(:company_wide),
        event: "announcement_published"
      ) || Notification.last.deliver_by_mail
    end

    def with_failing_delivery(exception)
      original = ActionMailer::Base.delivery_method
      FailingDeliveryMethod.exception = exception
      ActionMailer::Base.add_delivery_method :failing, FailingDeliveryMethod
      ActionMailer::Base.delivery_method = :failing

      yield
    ensure
      ActionMailer::Base.delivery_method = original
      FailingDeliveryMethod.exception = nil
    end
end
