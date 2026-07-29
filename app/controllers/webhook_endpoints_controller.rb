# Webhook の宛先の管理。
#
# 任意の URL へ送るため、登録できる利用者を管理者に限る。
class WebhookEndpointsController < ApplicationController
  before_action :require_administrator
  before_action :set_webhook_endpoint, only: %i[show update destroy]

  def index
    @webhook_endpoints = current_organization.webhook_endpoints.ordered
    @webhook_endpoint = current_organization.webhook_endpoints.new
  end

  def show
    @deliveries = @webhook_endpoint.webhook_deliveries.recent_first.limit(20)
  end

  def create
    @webhook_endpoint = current_organization.webhook_endpoints.new(webhook_endpoint_params)

    if @webhook_endpoint.save
      redirect_to webhook_endpoints_path, notice: t("webhook_endpoints.created")
    else
      @webhook_endpoints = current_organization.webhook_endpoints.ordered
      render :index, status: :unprocessable_content
    end
  end

  def update
    if @webhook_endpoint.update(webhook_endpoint_params)
      redirect_to webhook_endpoints_path, notice: t("webhook_endpoints.updated")
    else
      redirect_to webhook_endpoints_path, alert: @webhook_endpoint.errors.full_messages.to_sentence
    end
  end

  def destroy
    @webhook_endpoint.destroy

    redirect_to webhook_endpoints_path, notice: t("webhook_endpoints.destroyed"), status: :see_other
  end

  private
    def set_webhook_endpoint
      @webhook_endpoint = current_organization.webhook_endpoints.find(params[:id])
    end

    def webhook_endpoint_params
      params.expect(webhook_endpoint: %i[name url active])
    end
end
