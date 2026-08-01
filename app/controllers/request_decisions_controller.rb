# 申請の承認と差し戻し。
class RequestDecisionsController < ApplicationController
  # 決裁の種類と、行う処理・知らせる文の対応。
  #
  # キーを要求の値から組み立てない。組み立てると、想定外の値がそのまま
  # 翻訳キーになり、翻訳の欠落がそのまま画面へ出る。綴りの誤りにも
  # 気付けない。実際、"return" へ "d" を足す形で誤った綴りが固定されていた。
  DECISIONS = {
    "approve" => { action: :approve, notice: "approved" },
    "return" => { action: :return_to_applicant, notice: "returned" }
  }.freeze

  before_action :set_request
  before_action :require_decision_authorized

  def create
    decision = DECISIONS[params[:decision]]

    if decision && @request.public_send(decision[:action], actor: Current.user, comment: decision_comment)
      record_audit_event("request_#{@request.status}", target: @request, details: { title: @request.title })
      redirect_to @request, notice: t("request_decisions.#{decision[:notice]}")
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
    # 他の決裁が成立し得る。状態は行を占有した Request モデルだけが判断する。
    def require_decision_authorized
      return if @request.decision_authorized_for?(Current.user)

      render "shared/forbidden", status: :forbidden, formats: :html
    end

    def decision_comment
      params[:comment].presence
    end
end
