# 外部からの接続に使う token の管理。
#
# 発行できるのは自分の token だけとする。
# 他人の名前で発行できると、権限の出所が分からなくなる。
class ApiTokensController < ApplicationController
  before_action :set_api_token, only: %i[destroy]

  def index
    @api_tokens = Current.user.api_tokens.recent_first
    @api_token = Current.user.api_tokens.new
  end

  def create
    @api_token = Current.user.api_tokens.new(api_token_params)
    @api_token.organization = current_organization

    if @api_token.save
      # 値はこの一度だけ表示する。保存していないため、後から確認できない。
      flash[:issued_token] = @api_token.token
      record_audit_event("api_token_issued", target: @api_token, details: { name: @api_token.name })
      redirect_to api_tokens_path, notice: t("api_tokens.created")
    else
      @api_tokens = Current.user.api_tokens.recent_first
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    @api_token.revoke!
    record_audit_event("api_token_revoked", target: @api_token, details: { name: @api_token.name })

    redirect_to api_tokens_path, notice: t("api_tokens.revoked"), status: :see_other
  end

  private
    def set_api_token
      @api_token = Current.user.api_tokens.find(params[:id])
    end

    def api_token_params
      params.expect(api_token: %i[name])
    end
end
