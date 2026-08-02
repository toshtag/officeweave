# 稼働の異常を運用者へ知らせる。
#
# 定期実行から呼ぶ。宛先を設定していない場合と、異常が無い場合は送らない。
# 無事を毎日知らせると、通知そのものが読まれなくなる。
#
# 送信は worker のなかで完結させる。ここから別のジョブを積むと、
# 送信が滞っているときに、その事実を知らせるジョブも滞る。
class ReportOperationalIssuesJob < ApplicationJob
  queue_as :default

  def perform
    to = Officeweave::Configuration::OperationsEmail.current
    return if to.blank?

    report = OperationalReport.new
    return unless report.any?

    OperationsMailer.with(to: to, issues: report.issues).report.deliver_now
  end
end
