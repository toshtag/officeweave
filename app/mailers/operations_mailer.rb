# 運用者へ向けた送信。
#
# 業務の通知とは分ける。受け取るのは環境を預かる運用者であり、
# 利用者ごとの表示言語には従わない。既定の言語で組み立てる。
class OperationsMailer < ApplicationMailer
  def report
    @issues = params[:issues]

    I18n.with_locale(I18n.default_locale) do
      mail(
        to: params[:to],
        subject: t("operations_mailer.report.subject", count: @issues.size)
      )
    end
  end
end
