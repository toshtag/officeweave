# 申請種別の管理。参照は全員に開き、変更は管理者へ限定する。
class RequestTypesController < ApplicationController
  before_action :require_administrator, only: %i[new create edit update]
  before_action :set_request_type, only: %i[edit update]

  def index
    @request_types = current_organization.request_types.ordered.includes(:approver_department).to_a

    # 承認部門の階層を先に読む。行ごとに display_path を呼ぶと、
    # 件数と階層の深さの積だけ問い合わせが出る。
    Department.with_ancestors(@request_types.filter_map(&:approver_department))
  end

  def new
    @request_type = current_organization.request_types.new
  end

  def edit
  end

  def create
    @request_type = current_organization.request_types.new(request_type_params)

    if @request_type.save
      redirect_to request_types_path, notice: t("request_types.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @request_type.update(request_type_params)
      redirect_to request_types_path, notice: t("request_types.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  private
    def set_request_type
      @request_type = current_organization.request_types.find(params[:id])
    end

    def request_type_params
      params.expect(request_type: %i[name code description approver_department_id active position])
    end
end
