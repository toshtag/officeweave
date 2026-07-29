# 部門への所属の追加と解除。
class MembershipsController < ApplicationController
  before_action :require_administrator
  before_action :set_department

  def create
    membership = @department.memberships.new(membership_params)

    if membership.save
      record_audit_event("membership_created", target: membership,
                                               details: { department: @department.code, user_id: membership.user_id })
      redirect_to @department, notice: t("memberships.created")
    else
      redirect_to @department, alert: membership.errors.full_messages.to_sentence
    end
  end

  def destroy
    membership = @department.memberships.find(params[:id])
    membership.destroy
    record_audit_event("membership_deleted", details: { department: @department.code, user_id: membership.user_id })

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
