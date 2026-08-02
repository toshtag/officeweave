# パスワードの再設定の案内。
#
# 業務の通知とは分ける。配信設定の対象にしない。資格情報の再設定を、
# 利用者が受け取らない設定にできてはならない。
class PasswordMailer < ApplicationMailer
  def reset
    @user = params[:user]
    @token = @user.password_reset_token

    I18n.with_locale(@user.locale.presence || I18n.default_locale) do
      mail(to: @user.email_address, subject: t("password_mailer.reset.subject"))
    end
  end
end
