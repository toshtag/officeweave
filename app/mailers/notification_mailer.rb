# 通知のメール送信。
#
# 文面は受け取る利用者の表示言語で組み立てる。
# 送信元の設定に依存させると、利用者ごとに読める言語で届かない。
class NotificationMailer < ApplicationMailer
  def notify
    @notification = params[:notification]
    @user = @notification.user

    I18n.with_locale(@user.locale.presence || I18n.default_locale) do
      mail(
        to: @user.email_address,
        subject: t("notifications.events.#{@notification.event}", title: @notification.subject_title)
      )
    end
  end
end
