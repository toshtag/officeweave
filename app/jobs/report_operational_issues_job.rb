# 稼働の異常を運用者へ知らせる。
#
# 定期実行から呼ぶ。宛先を設定していない場合と、異常が無い場合は送らない。
# 無事を毎日知らせると、通知そのものが読まれなくなる。
#
# 同じ異常が続いているあいだも送り直さない。毎日同じ内容が届くと、
# 同じく読まれなくなる。知らせたことは記録に残し、一定の間隔を過ぎたときだけ
# 知らせ直す。読み流したまま忘れられると、知らせない期間がそのまま
# 放置の期間になる。
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
    # 記録の作成そのもので判断する。先に確かめてから書くと、定期実行が
    # 同時に二度動いたときに両方が通る。
    return unless OperationalAlert.claim(report.occurrence)

    OperationsMailer.with(to: to, issues: report.issues).report.deliver_now
  end
end
