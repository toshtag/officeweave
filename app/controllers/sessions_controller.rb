class SessionsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]

  # 総当たりによる推測を抑える。
  # 数え上げはキャッシュ領域に保持するため、複数の処理系で運用する場合は共有設定が必要になる。
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: t("sessions.rate_limited") }

  def new
  end

  def create
    user = User.authenticate_by(params.permit(:email_address, :password))

    # 無効化された利用者は、資格情報が正しくてもログインさせない。
    # 理由は区別して伝えない。無効化されていることを外から確かめる手段になる。
    if user&.active?
      start_new_session_for user
      redirect_to after_authentication_url, notice: t("sessions.signed_in")
    else
      # 該当する利用者がいないのか、パスワードが違うのかを区別して伝えない。
      # 区別すると、利用者の存在を確かめる手段になる。
      redirect_to new_session_path, alert: t("sessions.failed")
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other, notice: t("sessions.signed_out")
  end
end
