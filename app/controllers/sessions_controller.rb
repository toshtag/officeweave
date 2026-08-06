class SessionsController < ApplicationController
  records_audit :create, :destroy

  allow_unauthenticated_access only: %i[new create]

  # 総当たりによる推測を抑える。
  # 数え上げは web の外（RateLimitStore）で共有する。web ごとに数えると、
  # 台数を増やしただけで、利用者から見た上限がその数だけ増える。
  rate_limit to: 10, within: 3.minutes, only: :create,
             with: -> { redirect_to new_session_path, alert: t("sessions.rate_limited") },
             store: RateLimitStore

  def new
    @password_required = authentication_provider.password_required?
    # 認可サーバーへ送り出す入口を出すかどうか。
    # 設定が無い環境では、その経路そのものが無い。
    @oidc_available = authentication_provider.name_key == Authentication::OidcProvider.name_key &&
                      Authentication::Oidc.configured?
  end

  def create
    # 認証方式は設定で差し替えられる。既定は内部認証。
    # 無効にされた利用者を認証しない判断は、方式側が持つ。
    user = authentication_provider.authenticate(
      email_address: params[:email_address],
      password: params[:password]
    )

    if user
      start_new_session_for user
      record_audit_event("signed_in", target: user, organization: user.organization, actor: user)
      redirect_to after_authentication_url, notice: t("sessions.signed_in")
    else
      record_sign_in_failure
      # 該当する利用者がいないのか、資格情報が違うのかを区別して伝えない。
      # 区別すると、利用者の存在を確かめる手段になる。
      redirect_to new_session_path, alert: t("sessions.failed")
    end
  end

  def destroy
    record_audit_event("signed_out", target: Current.user)
    terminate_session
    redirect_to new_session_path, status: :see_other, notice: t("sessions.signed_out")
  end

  private
    # 失敗も記録する。組織が特定できない場合は残さない。
    # 誰の組織かが分からない記録は、後から追えない。
    def record_sign_in_failure
      user = User.find_by(email_address: params[:email_address].to_s.strip.downcase)
      return if user.nil?

      record_audit_event("sign_in_failed", organization: user.organization, actor: nil,
                                           details: { email_address: user.email_address })
    end
end
