require "test_helper"

# 稼働の異常を運用者へ知らせる定期実行。
#
# 宛先は業務の管理者ではなく、環境を預かる運用者とする。
# 送るのは異常があるときだけとし、無事を毎日知らせない。
class ReportOperationalIssuesJobTest < ActiveJob::TestCase
  include ActionMailer::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    ENV.delete("OPERATIONS_EMAIL")
  end

  test "宛先を設定していなければ送らない" do
    stub_report([ failure ]) do
      assert_no_emails { ReportOperationalIssuesJob.perform_now }
    end
  end

  test "異常が無ければ送らない" do
    ENV["OPERATIONS_EMAIL"] = "ops@example.com"

    stub_report([]) do
      assert_no_emails { ReportOperationalIssuesJob.perform_now }
    end
  end

  test "異常があれば運用者へ送る" do
    ENV["OPERATIONS_EMAIL"] = "ops@example.com"

    stub_report([ failure ]) do
      assert_emails 1 do
        ReportOperationalIssuesJob.perform_now
      end
    end

    mail = ActionMailer::Base.deliveries.last

    assert_equal [ "ops@example.com" ], mail.to
    assert_includes mail.subject, "1"
    assert_includes mail.body.to_s, "データベースへの接続"
    assert_includes mail.body.to_s, "接続できません"
  end

  test "確かめる手順を本文へ添える" do
    ENV["OPERATIONS_EMAIL"] = "ops@example.com"

    stub_report([ failure ]) do
      ReportOperationalIssuesJob.perform_now
    end

    # 知らせるだけで手が無いと、受け取った側は画面を開くところから始める。
    assert_includes ActionMailer::Base.deliveries.last.body.to_s, "bin/diagnose"
  end

  test "業務の通知とは別の宛先へ送る" do
    ENV["OPERATIONS_EMAIL"] = "ops@example.com"

    stub_report([ failure ]) do
      ReportOperationalIssuesJob.perform_now
    end

    # 利用者のメールアドレスへは送らない。運用の異常は業務の担当ではない。
    refute_includes ActionMailer::Base.deliveries.last.to, users(:taro).email_address
  end


  test "同じ異常が続くあいだは送り直さない" do
    ENV["OPERATIONS_EMAIL"] = "ops@example.com"

    stub_report([ failure ]) do
      ReportOperationalIssuesJob.perform_now
      ReportOperationalIssuesJob.perform_now
    end

    # 毎日同じ内容が届くと、通知そのものが読まれなくなる。
    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "送ったことを記録に残す" do
    ENV["OPERATIONS_EMAIL"] = "ops@example.com"

    stub_report([ failure ]) do
      ReportOperationalIssuesJob.perform_now
    end

    # 記録がないと、送っていないのか届かなかったのかを区別できない。
    assert_equal 1, OperationalAlert.count
  end

  test "異常が変われば改めて送る" do
    ENV["OPERATIONS_EMAIL"] = "ops@example.com"

    stub_report([ failure ]) { ReportOperationalIssuesJob.perform_now }
    stub_report([ failure, another_failure ]) { ReportOperationalIssuesJob.perform_now }

    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  test "間隔を過ぎれば、同じ異常でも知らせ直す" do
    ENV["OPERATIONS_EMAIL"] = "ops@example.com"

    stub_report([ failure ]) do
      ReportOperationalIssuesJob.perform_now

      travel OperationalAlert::REMINDER_INTERVAL + 1.day do
        ReportOperationalIssuesJob.perform_now
      end
    end

    # 読み流したまま忘れられると、知らせない期間がそのまま放置の期間になる。
    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  test "宛先が無ければ記録も残さない" do
    ENV["OPERATIONS_EMAIL"] = nil

    stub_report([ failure ]) { ReportOperationalIssuesJob.perform_now }

    assert_equal 0, OperationalAlert.count
  end

  private
    def another_failure
      { name: "メールの送信", status: :error, detail: "送信できません", notify: true }
    end

    def failure
      { name: "データベースへの接続", status: :error, detail: "接続できません", notify: true }
    end

    # 実際の構成を壊さずに、異常のある状態を作る。
    def stub_report(checks)
      original = OperationalReport.method(:new)
      OperationalReport.define_singleton_method(:new) { |**| original.call(checks: checks) }
      yield
    ensure
      OperationalReport.singleton_class.remove_method(:new)
    end
end
