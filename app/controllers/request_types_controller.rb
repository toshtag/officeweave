# 申請種別の管理。参照は全員に開き、変更は管理者へ限定する。
class RequestTypesController < ApplicationController
  # 承認の経路そのものを決める。誰が何を承認できるかが変わるため記録する。
  records_audit :create, :update

  before_action :require_administrator, only: %i[new create edit update]
  before_action :set_request_type, only: %i[edit update]

  def index
    @page = Pagination.new(current_organization.request_types.ordered
                                              .includes(approval_steps: :approver_department),
                           page: params[:page])
    @request_types = @page.records

    # 承認部門の階層を先に読む。行ごとに display_path を呼ぶと、
    # 件数と階層の深さの積だけ問い合わせが出る。
    Department.with_ancestors(@request_types.flat_map(&:approval_steps).filter_map(&:approver_department))
  end

  def new
    @request_type = current_organization.request_types.new
  end

  def edit
  end

  def create
    @request_type = current_organization.request_types.new(request_type_params)

    if @request_type.save
      record_route_change("request_type_created")
      redirect_to request_types_path, notice: t("request_types.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @request_type.update(request_type_params)
      record_route_change("request_type_updated")
      redirect_to request_types_path, notice: t("request_types.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    # 詳細には、識別に必要な値と承認の段だけを置く。説明文は入れない。
    # 監査は誰が経路を変えたかを追うためのものであり、文面の履歴ではない。
    def record_route_change(action)
      record_audit_event(action, target: @request_type,
                                 details: { code: @request_type.code,
                                            approver_department_ids: approver_department_ids })
    end

    # 承認の段は、順と承認する部門だけを残す。ここが変わると、誰が承認できるかが変わる。
    def approver_department_ids
      @request_type.approval_steps.reject(&:marked_for_destruction?)
                   .sort_by(&:position).map(&:approver_department_id)
    end

    def set_request_type
      @request_type = current_organization.request_types.find(params[:id])
    end

    def request_type_params
      params.expect(request_type: [ :name, :code, :description, :active, :position,
                                   { approval_steps_attributes: [ %i[id position approver_department_id _destroy] ] } ])
    end
end
