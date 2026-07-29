# 申請の提出と取り下げ。
#
# 状態を変える操作を、申請そのものの更新と分けている。
# 同じ更新経路に混ぜると、本文の修正と状態の変更を区別できなくなる。
class RequestSubmissionsController < ApplicationController
  before_action :set_request

  # 提出する。
  def create
    unless @request.applicant_id == Current.user.id
      return render "shared/forbidden", status: :forbidden, formats: :html
    end

    if @request.submit
      redirect_to @request, notice: t("requests.submitted")
    else
      redirect_to @request, alert: t("requests.cannot_submit")
    end
  end

  # 取り下げる。
  def destroy
    unless @request.withdrawable_by?(Current.user)
      return render "shared/forbidden", status: :forbidden, formats: :html
    end

    @request.withdraw

    redirect_to @request, notice: t("requests.withdrawn"), status: :see_other
  end

  private
    def set_request
      @request = Request.visible_to(Current.user).find(params[:request_id])
    end
end
