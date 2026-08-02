# 承認の委任。
#
# 扱えるのは自分の委任だけとする。他人の委任を作れると、担当していない
# 相手の権限を誰かが横から広げられる。
#
# 管理者にも他人の委任は扱わせない。不在の申し出は本人から出る。
class ApprovalDelegationsController < ApplicationController
  def index
    @delegations = Current.user.approval_delegations_as_delegator.recent_first.includes(:delegate)
    @delegation = Current.user.approval_delegations_as_delegator.new(starts_on: Date.current)
  end

  def create
    @delegation = Current.user.approval_delegations_as_delegator.new(delegation_params)
    @delegation.organization = current_organization

    if @delegation.save
      record_audit_event("approval_delegation_created", target: @delegation,
                                                       details: { delegate: @delegation.delegate.name })
      redirect_to approval_delegations_path, notice: t("approval_delegations.created")
    else
      @delegations = Current.user.approval_delegations_as_delegator.recent_first.includes(:delegate)
      render :index, status: :unprocessable_content
    end
  end

  def destroy
    delegation = Current.user.approval_delegations_as_delegator.find_by(id: params[:id])

    return head :not_found if delegation.nil?

    delegation.destroy
    record_audit_event("approval_delegation_deleted", details: { delegate: delegation.delegate.name })

    redirect_to approval_delegations_path, notice: t("approval_delegations.deleted"), status: :see_other
  end

  private
    def delegation_params
      params.expect(approval_delegation: %i[delegate_id starts_on ends_on])
    end
end
