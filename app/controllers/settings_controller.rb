# 利用者が自分で変更できる設定。
#
# 管理者による利用者の管理とは別の画面にする。
# 同じ画面にすると、自分の設定と他人の設定の区別が付きにくい。
class SettingsController < ApplicationController
  def show
    @user = Current.user
  end

  def update
    @user = Current.user

    if @user.update(user_params) && update_notification_preferences
      # 表示言語を変えた直後は、変更後の言語で知らせる。
      # 変更前の言語で出すと、読めない言語のまま結果が示される。
      redirect_to settings_path, notice: updated_message
    else
      render :show, status: :unprocessable_content
    end
  end

  private
    def updated_message
      I18n.with_locale(@user.locale.presence || I18n.locale) { t("settings.updated") }
    end

    def user_params
      params.expect(user: %i[locale])
    end

    # 送られてこなかった種類は受け取らない設定にする。
    # 未選択と未送信を区別できないため、画面の状態をそのまま反映する。
    def update_notification_preferences
      enabled = Array(params[:mail_notifications])

      Notification::EVENTS.each do |event|
        preference = Current.user.notification_preferences.find_or_initialize_by(event: event)
        preference.mail_enabled = enabled.include?(event)
        preference.save!
      end

      true
    end
end
