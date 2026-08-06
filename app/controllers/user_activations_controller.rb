# 利用者の有効化と無効化。
#
# 利用者そのものを削除する経路は用意しない。
# 削除すると、過去の申請や監査の記録から利用者をたどれなくなる。
class UserActivationsController < ApplicationController
  records_audit :create, :destroy

  before_action :require_administrator
  before_action :set_user

  def create
    @user.activate!
    record_audit_event("user_activated", target: @user, details: { email_address: @user.email_address })

    redirect_to users_path, notice: t("users.activated")
  end

  def destroy
    # 自分自身を無効化すると、その場で操作できなくなる。
    if @user == Current.user
      return redirect_to users_path, alert: t("users.cannot_deactivate_self"), status: :see_other
    end

    @user.deactivate!
    record_audit_event("user_deactivated", target: @user, details: { email_address: @user.email_address })

    redirect_to users_path, notice: t("users.deactivated"), status: :see_other
  end

  private
    def set_user
      @user = current_organization.users.find(params[:user_id])
    end
end
