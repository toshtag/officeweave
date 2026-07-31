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

    if @request.submit(actor: Current.user)
      redirect_to @request, notice: t("requests.submitted")
    else
      redirect_to @request, alert: t("requests.cannot_submit")
    end
  end

  # 取り下げる。
  #
  # 受け入れでは申請者本人であることだけを確かめる。
  # 現在の状態は確かめても、実際に取り下げるまでの間に決裁が成立し得る。
  # 状態は行を占有した Request モデルだけが判断し、ここはその結果を伝える。
  def destroy
    unless @request.applicant_id == Current.user.id
      return render "shared/forbidden", status: :forbidden, formats: :html
    end

    if @request.withdraw(actor: Current.user)
      redirect_to @request, notice: t("requests.withdrawn"), status: :see_other
    else
      redirect_to @request, alert: t("requests.cannot_withdraw"), status: :see_other
    end
  end

  private
    def set_request
      @request = Request.visible_to(Current.user).find(params[:request_id])
    end
end
