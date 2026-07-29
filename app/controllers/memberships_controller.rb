# 部門への所属の追加と解除。
# 操作できる利用者の範囲は P4-T3 で権限を導入した時点で絞る。
class MembershipsController < ApplicationController
  before_action :set_department

  def create
    membership = @department.memberships.new(membership_params)

    if membership.save
      redirect_to @department, notice: t("memberships.created")
    else
      redirect_to @department, alert: membership.errors.full_messages.to_sentence
    end
  end

  def destroy
    membership = @department.memberships.find(params[:id])
    membership.destroy

    redirect_to @department, notice: t("memberships.destroyed"), status: :see_other
  end

  private
    def set_department
      @department = current_organization.departments.find(params[:department_id])
    end

    def membership_params
      params.expect(membership: %i[user_id primary])
    end
end
