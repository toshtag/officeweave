# 承認の委任。
#
# 扱えるのは自分の委任だけとする。他人の委任を作れると、担当していない
# 相手の権限を誰かが横から広げられる。
#
# 管理者にも他人の委任は扱わせない。不在の申し出は本人から出る。
class ApprovalDelegationsController < ApplicationController
  records_audit :create, :destroy

  def index
    @page = Pagination.new(Current.user.approval_delegations_as_delegator.recent_first.includes(:delegate),
                           page: params[:page])
    @delegations = @page.records
    @delegation = Current.user.approval_delegations_as_delegator.new(starts_on: Date.current)
    # 委任先の候補は上限を置く。全件描くと、描く量が組織の人数に比例する。
    @delegate_candidates = Candidates.new(
      current_organization.users.active.where.not(id: Current.user.id).ordered,
      query: params[:delegate_query], selected_ids: [ @delegation.delegate_id ]
    )
  end

  def create
    @delegation = Current.user.approval_delegations_as_delegator.new(delegation_params)
    @delegation.organization = current_organization

    if @delegation.save_with_overlap_check
      record_audit_event("approval_delegation_created", target: @delegation,
                                                       details: { delegate: @delegation.delegate.name })
      redirect_to approval_delegations_path, notice: t("approval_delegations.created")
    else
      @page = Pagination.new(Current.user.approval_delegations_as_delegator.recent_first.includes(:delegate),
                             page: params[:page])
      @delegations = @page.records
      @delegate_candidates = Candidates.new(
        current_organization.users.active.where.not(id: Current.user.id).ordered,
        query: params[:delegate_query], selected_ids: [ @delegation.delegate_id ]
      )
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
