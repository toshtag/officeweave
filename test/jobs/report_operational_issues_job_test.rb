require "test_helper"

# 稼働の異常を運用者へ知らせる定期実行。
#
# 宛先は業務の管理者ではなく、環境を預かる運用者とする。
# 送るのは異常があるときだけとし、無事を毎日知らせない。
class ReportOperationalIssuesJobTest < ActiveJob::TestCase
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

  private
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
