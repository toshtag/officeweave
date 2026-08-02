# 自分のパスワードの変更。
#
# 管理者による変更（利用者の管理）とは別の経路とする。自分の変更では、
# 今のパスワードを知っていることを求める。求めないと、開いたままの画面を
# 使える相手が、資格情報を置き換えて利用者を締め出せる。
#
# パスワードを扱わない認証方式では、この経路自体を無いものとする。
# 資格情報がこの製品の中に無いため、変えられるものが無い。
class PasswordsController < ApplicationController
  before_action :require_internal_credentials

  def edit
    @user = Current.user
  end

  def update
    @user = Current.user

    unless @user.authenticate(params[:current_password].to_s)
      # 何を直すのかを示す。理由を出さずに 422 だけを返すと、利用者は
      # 今のパスワードと新しいパスワードのどちらを直すのか分からない。
      #
      # 属性としては足さない。今のパスワードは利用者の属性ではなく、
      # この経路だけが受け取る確認の入力である。
      @user.errors.add(:base, :current_password_invalid)

      return render :edit, status: :unprocessable_content
    end

    if @user.update(password_params)
      # 変更で自分のセッションも終わる（User#discard_sessions）。
      # 操作した端末だけは、あらためて開き直す。変更のたびにログイン画面へ
      # 戻す形にすると、それが変更をためらう理由になる。
      start_new_session_for(@user)
      record_audit_event("password_changed", target: @user)

      redirect_to settings_path, notice: t("passwords.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def password_params
      params.expect(user: %i[password password_confirmation])
    end

    def require_internal_credentials
      return if password_credentials?

      # 「権限が無い」ではなく「その経路が無い」として扱う。
      # 方式を切り替えた環境では、変更できる資格情報が存在しない。
      head :not_found
    end
end
