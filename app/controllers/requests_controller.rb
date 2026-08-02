# 申請の作成、提出、取り下げ。
# 承認と差し戻しは P7-T2 で扱う。
class RequestsController < ApplicationController
  before_action :set_request, only: %i[show edit update]
  before_action :require_editable, only: %i[edit update]

  # 一覧の対象。
  #   mine     自分が出した申請
  #   awaiting 自分の処理を待っている申請
  #   （未指定）参照できる申請すべて
  SCOPES = %w[mine awaiting].freeze

  def index
    @scope = params[:scope].presence_in(SCOPES)
    @status = params[:status]
    @page = Pagination.new(scoped_requests.with_status(@status).recent_first
                                          .includes(:request_type, :applicant),
                          page: params[:page])
    @requests = @page.records
    @awaiting_count = Request.awaiting_decision_by(Current.user).count
  end

  def show
    @activities = @request.request_activities.chronological.includes(:actor)
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
      @request.record_creation(actor: Current.user)
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
    def scoped_requests
      case @scope
      when "mine" then Request.visible_to(Current.user).applied_by(Current.user)
      when "awaiting" then Request.awaiting_decision_by(Current.user)
      else Request.visible_to(Current.user)
      end
    end

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
