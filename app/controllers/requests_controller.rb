# 申請の作成、提出、取り下げ。
# 承認と差し戻しは P7-T2 で扱う。
class RequestsController < ApplicationController
  before_action :set_request, only: %i[show edit update]
  before_action :require_editable, only: %i[edit update]

  def index
    @status = params[:status]
    @requests = Request.visible_to(Current.user)
                       .with_status(@status)
                       .recent_first
                       .includes(:request_type, :applicant)
  end

  def show
  end

  def new
    @request = current_organization.requests.new(request_type_id: params[:request_type_id])
  end

  def edit
  end

  def create
    @request = current_organization.requests.new(request_params)
    @request.applicant = Current.user

    if @request.save
      redirect_to @request, notice: t("requests.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @request.update(request_params.except(:request_type_id))
      redirect_to @request, notice: t("requests.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_request
      @request = Request.visible_to(Current.user).find(params[:id])
    end

    def require_editable
      return if @request.editable_by?(Current.user)

      render "shared/forbidden", status: :forbidden, formats: :html
    end

    def request_params
      params.expect(request: %i[request_type_id title body])
    end
end
