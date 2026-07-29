# 部門の一覧と管理。
# 操作できる利用者の範囲は P4-T3 で権限を導入した時点で絞る。
class DepartmentsController < ApplicationController
  before_action :set_department, only: %i[show edit update destroy]

  def index
    @departments = current_organization.departments.ordered.includes(:parent)
  end

  def show
    @memberships = @department.memberships.includes(:user).joins(:user).merge(User.ordered)
    @assignable_users = current_organization.users.ordered.where.not(id: @department.user_ids)
  end

  def new
    @department = current_organization.departments.new
  end

  def edit
  end

  def create
    @department = current_organization.departments.new(department_params)

    if @department.save
      redirect_to @department, notice: t("departments.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @department.update(department_params)
      redirect_to @department, notice: t("departments.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @department.destroy
      redirect_to departments_path, notice: t("departments.destroyed"), status: :see_other
    else
      redirect_to @department, alert: @department.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private
    def set_department
      @department = current_organization.departments.find(params[:id])
    end

    def department_params
      params.expect(department: %i[name code parent_id position])
    end
end
