# Webhook の宛先の管理。
#
# 任意の URL へ送るため、登録できる利用者を管理者に限る。
class WebhookEndpointsController < ApplicationController
  records_audit :create, :update, :destroy

  before_action :require_administrator
  before_action :set_webhook_endpoint, only: %i[show update destroy]

  def index
    @page = Pagination.new(current_organization.webhook_endpoints.ordered, page: params[:page])
    @webhook_endpoints = @page.records
    @webhook_endpoint = current_organization.webhook_endpoints.new
  end

  def show
    @deliveries = @webhook_endpoint.webhook_deliveries.recent_first.limit(20)
  end

  def create
    @webhook_endpoint = current_organization.webhook_endpoints.new(webhook_endpoint_params)

    if @webhook_endpoint.save
      record_audit_event("webhook_endpoint_created", target: @webhook_endpoint,
                                                     details: { url: @webhook_endpoint.url })
      redirect_to webhook_endpoints_path, notice: t("webhook_endpoints.created")
    else
      @page = Pagination.new(current_organization.webhook_endpoints.ordered, page: params[:page])
      @webhook_endpoints = @page.records
      render :index, status: :unprocessable_content
    end
  end

  def update
    if @webhook_endpoint.update(webhook_endpoint_params)
      record_update_audit_event
      redirect_to webhook_endpoints_path, notice: t("webhook_endpoints.updated")
    else
      redirect_to webhook_endpoints_path, alert: @webhook_endpoint.errors.full_messages.to_sentence
    end
  end

  def destroy
    @webhook_endpoint.destroy
    record_audit_event("webhook_endpoint_deleted", details: { url: @webhook_endpoint.url })

    redirect_to webhook_endpoints_path, notice: t("webhook_endpoints.destroyed"), status: :see_other
  end

  private
    # 変更の前後を残す。変更後だけでは、どこから差し替わったのかが分からない。
    #
    # 送信の記録は、どの宛先へ送ったかを URL では持たず、現在の宛先を指す
    # 関連として持つ。過去の送信が実際にどこへ届いたのかは、この記録から
    # しか辿れない。
    #
    # 値が変わった保存だけを残す。変わらない保存まで残すと、差し替えの
    # 痕跡が同じ内容の記録に埋もれる。
    #
    # secret は残さない。監査記録は管理者が画面で読むものであり、受け取る
    # 側の検証に使う値をそこへ複製しない。
    AUDITED_ATTRIBUTES = %w[url active].freeze

    def record_update_audit_event
      changes = @webhook_endpoint.previous_changes.slice(*AUDITED_ATTRIBUTES)
      return if changes.empty?

      record_audit_event("webhook_endpoint_updated", target: @webhook_endpoint,
                                                     details: audit_details(changes))
    end

    # 変わらなかった項目も現在の値として残す。URL だけの差し替えなのか、
    # 停止を伴うのかを、記録 1 件で判断できるようにする。
    def audit_details(changes)
      details = AUDITED_ATTRIBUTES.index_with { |name| @webhook_endpoint.public_send(name) }

      changes.each { |name, (before, _after)| details["previous_#{name}"] = before }
      details
    end

    def set_webhook_endpoint
      @webhook_endpoint = current_organization.webhook_endpoints.find(params[:id])
    end

    def webhook_endpoint_params
      params.expect(webhook_endpoint: %i[name url active])
    end
end
