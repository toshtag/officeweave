# 申請の承認と差し戻し。
class RequestDecisionsController < ApplicationController
  before_action :set_request
  before_action :require_decision_authorized

  def create
    result =
      case params[:decision]
      when "approve" then @request.approve(actor: Current.user, comment: decision_comment)
      when "return" then @request.return_to_applicant(actor: Current.user, comment: decision_comment)
      end

    if result
      record_audit_event("request_#{@request.status}", target: @request, details: { title: @request.title })
      redirect_to @request, notice: t("request_decisions.#{params[:decision]}d")
    else
      redirect_to @request, alert: t("request_decisions.failed")
    end
  end

  private
    def set_request
      @request = Request.visible_to(Current.user).find(params[:request_id])
    end

    # ここで確かめるのは立場だけにする。立場は種別に指定した部門と権限で決まり、
    # 自分の申請を自分で承認することは認めない。
    #
    # 現在の状態は確かめない。ここで確かめても、実際に処理するまでの間に
    # 他の決裁が成立し得る。状態は行を占有した模型側だけが判断する。
    def require_decision_authorized
      return if @request.decision_authorized_for?(Current.user)

      render "shared/forbidden", status: :forbidden, formats: :html
    end

    def decision_comment
      params[:comment].presence
    end
end
