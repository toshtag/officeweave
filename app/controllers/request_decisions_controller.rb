# 申請の承認と差し戻し。
class RequestDecisionsController < ApplicationController
  before_action :set_request
  before_action :require_decidable

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

    # 承認できる立場かどうかは、種別に指定した部門と権限で決まる。
    # 自分の申請を自分で承認することは認めない。
    def require_decidable
      return if @request.decidable_by?(Current.user)

      render "shared/forbidden", status: :forbidden, formats: :html
    end

    def decision_comment
      params[:comment].presence
    end
end
