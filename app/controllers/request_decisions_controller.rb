# 申請の承認と差し戻し。
class RequestDecisionsController < ApplicationController
  # 決裁の種類と、行う処理・知らせる文の対応。
  #
  # キーを要求の値から組み立てない。組み立てると、想定外の値がそのまま
  # 翻訳キーになり、翻訳の欠落がそのまま画面へ出る。綴りの誤りにも
  # 気付けない。実際、"return" へ "d" を足す形で誤った綴りが固定されていた。
  DECISIONS = {
    "approve" => { decision: :approve, notice: "approved" },
    "return" => { decision: :return, notice: "returned" }
  }.freeze

  before_action :set_request

  def create
    decision = DECISIONS[params[:decision]]
    return redirect_to @request, alert: t("request_decisions.failed") if decision.nil?

    result = RequestDecision.call(
      request: @request, actor: Current.user, decision: decision[:decision],
      expected_step_position: expected_step_position, comment: decision_comment,
      ip_address: request.remote_ip
    )

    respond_to_outcome(result.outcome, decision[:notice])
  end

  private
    def set_request
      @request = Request.visible_to(Current.user).find(params[:request_id])
    end

    # 結果を応答の形へ写すだけにする。ここで判断をやり直すと、占有のなかで
    # 決めた結果と、画面へ返す結果が食い違い得る。
    def respond_to_outcome(outcome, notice)
      case outcome
      when :success
        redirect_to @request, notice: t("request_decisions.#{notice}")
      when :stale
        # 見ていた段と、いま待っている段が違う。やり直せば通る種類の失敗で
        # あるため、立場の拒否とは分ける。
        render "requests/conflict", status: :conflict, formats: :html
      when :unauthorized
        render "shared/forbidden", status: :forbidden, formats: :html
      else
        redirect_to @request, alert: t("request_decisions.failed")
      end
    end

    # 画面が見ていた段。送られない場合は、期待が無いものとして競合に倒す。
    #
    # 無指定を「いま待っている段」として扱わない。扱うと、すべての段を担当
    # する利用者の二重送信で、段を 2 つ進められる。
    def expected_step_position
      Integer(params[:expected_step_position], exception: false)
    end

    def decision_comment
      params[:comment].presence
    end
end
