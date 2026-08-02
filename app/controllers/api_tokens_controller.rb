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
    @api_token = Current.user.api_tokens.new(name: api_token_params[:name])
    @api_token.organization = current_organization
    @api_token.expires_at = requested_expiry
    # 画面では必ず選ぶ。指定が無いことを「すべて」として扱うのは、
    # この版より前に発行した token のためである。
    @api_token.scopes = Array(api_token_params[:scopes])

    if @expiry_days_invalid
      # 候補にない日数は、期限の指定として受け取らない。
      @api_token.errors.add(:expires_at, :not_a_choice)
    elsif @api_token.save
      # 値はこの一度だけ表示する。保存していないため、後から確認できない。
      flash[:issued_token] = @api_token.token
      record_audit_event("api_token_issued", target: @api_token,
                                             details: { name: @api_token.name,
                                                        expires_in_days: @expiry_days,
                                                        scopes: @api_token.scopes }.compact)
      return redirect_to api_tokens_path, notice: t("api_tokens.created")
    end

    @api_tokens = Current.user.api_tokens.recent_first
    render :index, status: :unprocessable_content
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
      params.expect(api_token: [ :name, :expires_in_days, { scopes: [] } ])
    end

    # 期限は日数で受け取り、決めた候補だけを認める。
    #
    # 時刻をそのまま受け取らない。受け取ると、過去の時刻や 10 年後を
    # 画面から指定できる。空欄は「期限なし」とする。
    def requested_expiry
      raw = api_token_params[:expires_in_days].to_s

      return nil if raw.blank?

      @expiry_days = raw.to_i
      @expiry_days_invalid = !ApiToken::EXPIRY_CHOICES.include?(@expiry_days)

      @expiry_days.days.from_now unless @expiry_days_invalid
    end
end
