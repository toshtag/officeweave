# 部門の一覧と管理。
# 参照は所属の確認に使うため全員に開き、変更は管理者へ限定する。
class DepartmentsController < ApplicationController
  records_audit :create, :update, :destroy

  before_action :require_administrator, only: %i[new create edit update destroy]
  before_action :set_department, only: %i[show edit update destroy]

  def index
    @page = Pagination.new(current_organization.departments.ordered.includes(:parent),
                           page: params[:page])
    # 階層の表示は 1 ページ分だけへ広げる。全件へ広げると、上限を置いた
    # 意味が無くなる。
    @departments = Department.with_ancestors(@page.records)
  end

  def show
    @memberships = @department.memberships.includes(:user).joins(:user).merge(User.ordered)
    # 候補は上限を置いて並べる。全件描くと、描く量が組織の人数に比例する。
    @assignable_users = Candidates.new(
      current_organization.users.ordered.where.not(id: @department.user_ids),
      query: params[:user_query]
    )
  end

  def new
    @department = current_organization.departments.new
    @parent_candidates = parent_candidates
  end

  def edit
    @parent_candidates = parent_candidates(except: @department)
  end

  def create
    @department = current_organization.departments.new(department_params)

    if @department.save_with_cycle_check
      record_audit_event("department_created", target: @department, details: { code: @department.code })
      redirect_to @department, notice: t("departments.created")
    else
      @parent_candidates = parent_candidates
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @department.update_with_cycle_check(department_params)
      record_audit_event("department_updated", target: @department, details: { code: @department.code })
      redirect_to @department, notice: t("departments.updated")
    else
      @parent_candidates = parent_candidates(except: @department)
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @department.destroy
      record_audit_event("department_deleted", details: { code: @department.code, name: @department.name })
      redirect_to departments_path, notice: t("departments.destroyed"), status: :see_other
    else
      redirect_to @department, alert: @department.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private
    # 上位に選べる部門。全件描くと、描く量が部門の数に比例する。
    def parent_candidates(except: nil)
      scope = current_organization.departments.ordered
      scope = scope.where.not(id: except.id) if except

      Candidates.new(scope, query: params[:parent_query], selected_ids: [ @department&.parent_id ])
    end

    def set_department
      @department = current_organization.departments.find(params[:id])
    end

    def department_params
      params.expect(department: %i[name code parent_id position])
    end
end
