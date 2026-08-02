# パスワードの再設定。
#
# 今のパスワードを思い出せない利用者のための経路である。管理者を通さずに
# 資格情報を置き換えられるため、受け取れる相手をメールの宛先だけに限る。
#
# 応答は、利用者がいてもいなくても同じにする。違えると、組織に属する
# メールアドレスの一覧をこの経路から作れる。
class PasswordResetsController < ApplicationController
  allow_unauthenticated_access
  before_action :require_internal_credentials

  # 総当たりと、宛先へ大量に送りつけることを抑える。
  # 数え上げはキャッシュ領域に保持するため、複数の処理系で運用する場合は共有設定が必要になる。
  rate_limit to: 5, within: 3.minutes, only: :create,
             with: -> { redirect_to new_password_reset_path, alert: t("password_resets.rate_limited") }

  before_action :set_user_from_token, only: %i[edit update]

  def new
  end

  def create
    user = User.active.find_by(email_address: params[:email_address].to_s.strip.downcase)

    if user
      PasswordMailer.with(user: user).reset.deliver_later
      record_audit_event("password_reset_requested", organization: user.organization,
                                                     actor: nil, target: user)
    end

    # 送ったかどうかを応答から読み取れないようにする。
    redirect_to new_session_path, notice: t("password_resets.sent")
  end

  def edit
  end

  def update
    if @user.update(password_params)
      # 再設定でその利用者のセッションはすべて終わる（User#discard_sessions）。
      # ここでログインを開き直さない。案内のメールを読める相手が、そのまま
      # ログイン状態になることはしない。
      record_audit_event("password_reset_completed", organization: @user.organization,
                                                     actor: nil, target: @user)

      redirect_to new_session_path, notice: t("password_resets.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def password_params
      params.expect(user: %i[password password_confirmation])
    end

    # 案内の値は、期限と用途を含めて署名してある。
    # 読み取れない、期限を過ぎた、パスワードが変わった後の値は受け付けない。
    def set_user_from_token
      @user = User.find_by_password_reset_token(params[:token])
      @token = params[:token]

      return if @user&.active?

      redirect_to new_password_reset_path, alert: t("password_resets.invalid_token")
    end

    def require_internal_credentials
      return if password_credentials?

      head :not_found
    end
end
