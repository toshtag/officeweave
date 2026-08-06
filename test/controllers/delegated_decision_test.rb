require "test_helper"

# 委任を受けた利用者が、画面から代理で決裁できること。
#
# 委任は担当を移さないが、決裁できる範囲は広がる。その範囲は、決裁の立場、
# 承認待ちの一覧、申請の参照、通知の対象の 4 か所で使う。別々に組み立てると、
# 模型では代理で決裁できるのに画面からは申請を開けない、という食い違いが出る。
class DelegatedDecisionTest < ActionDispatch::IntegrationTest
  # 部門を担当する段の委任。委任先は、自分ではどの部門にも所属しない。
  test "部門の段を委ねられた利用者は、一覧から開いて承認できる" do
    request = requests(:taro_leave_pending)
    delegate = delegate_of(users(:approver))

    assert_delegated_paths_agree(request, delegate)

    sign_in_as delegate
    get request_url(request)

    assert_response :success
    assert_select "input[name=state_token]"

    post request_decision_url(request),
         params: { decision: "approve", expected_step_position: request.current_step.position,
                   state_token: request.decision_state_token_for(delegate) }

    assert_redirected_to request
    assert_equal "approved", request.reload.status

    activity = request.request_activities.where(action: "approved").sole

    assert_equal delegate, activity.actor
    assert_equal users(:approver), activity.on_behalf_of
  end

  # 部門を指定しない段は管理者が担当する。その段の委任も同じように通す。
  test "管理者の段を委ねられた利用者は、一覧から開いて差し戻せる" do
    request = requests(:hanako_expense_pending)
    delegate = delegate_of(users(:taro))

    assert_delegated_paths_agree(request, delegate)

    sign_in_as delegate
    get request_url(request)

    assert_response :success

    post request_decision_url(request),
         params: { decision: "return", expected_step_position: request.current_step.position,
                   state_token: request.decision_state_token_for(delegate) }

    assert_redirected_to request
    assert_equal "returned", request.reload.status
    assert_equal users(:taro), request.request_activities.where(action: "returned").sole.on_behalf_of
  end

  test "委任が終わると、4 つの経路がそろって拒む" do
    request = requests(:taro_leave_pending)
    delegate = delegate_of(users(:approver))

    ApprovalDelegation.where(delegate_id: delegate.id).update_all(ends_on: Date.yesterday)

    assert_delegated_paths_deny(request, delegate)
  end

  test "委任元を無効にすると、4 つの経路がそろって拒む" do
    request = requests(:taro_leave_pending)
    delegate = delegate_of(users(:approver))

    users(:approver).update!(deactivated_at: Time.current)

    assert_delegated_paths_deny(request, delegate)
  end

  test "委任元の所属が外れると、4 つの経路がそろって拒む" do
    request = requests(:taro_leave_pending)
    delegate = delegate_of(users(:approver))

    users(:approver).memberships.destroy_all

    assert_delegated_paths_deny(request, delegate)
  end

  test "委任元が管理者でなくなると、管理者の段で 4 つの経路がそろって拒む" do
    request = requests(:hanako_expense_pending)
    delegate = delegate_of(users(:taro))

    organizations(:main).users.create!(name: "別の管理者", email_address: "keeper@example.com",
                                       password: "a-long-secret-value", role: "administrator")
    users(:taro).update!(role: "member")

    assert_delegated_paths_deny(request, delegate)
  end

  test "委任先を無効にすると、4 つの経路がそろって拒む" do
    request = requests(:taro_leave_pending)
    delegate = delegate_of(users(:approver))

    delegate.update!(deactivated_at: Time.current)

    assert_delegated_paths_deny(request, delegate)
  end

  # 委任は組織の境界を越えない。
  test "別の組織の申請は、委任があっても届かない" do
    request = requests(:taro_leave_pending)
    outsider = users(:outsider)

    assert_not Request.visible_to(outsider).exists?(id: request.id)
    assert_not Request.awaiting_decision_by(outsider).exists?(id: request.id)
    assert_not request.decision_authorized_for?(outsider)
  end

  test "委任を受けていても、自分の申請は決裁できない" do
    request = requests(:hanako_expense_pending)
    delegate = users(:hanako)
    organizations(:main).approval_delegations.create!(delegator: users(:taro), delegate: delegate,
                                                      starts_on: Date.current)

    assert_not request.decision_authorized_for?(delegate)
    assert_not Request.awaiting_decision_by(delegate).exists?(id: request.id)
    assert_not request.approvers.exists?(id: delegate.id)
  end

  private
    def delegate_of(delegator)
      delegate = users(:outsider_free)
      organizations(:main).approval_delegations.create!(delegator: delegator, delegate: delegate,
                                                        starts_on: Date.current)
      delegate
    end

    # 4 つの経路が、そろって通すこと。
    def assert_delegated_paths_agree(request, delegate)
      assert request.decision_authorized_for?(delegate), "決裁の立場が無い"
      assert Request.awaiting_decision_by(delegate).exists?(id: request.id), "承認待ちの一覧に無い"
      assert Request.visible_to(delegate).exists?(id: request.id), "参照できない"
      assert request.approvers.exists?(id: delegate.id), "通知の対象に無い"
    end

    # 4 つの経路が、そろって拒むこと。
    def assert_delegated_paths_deny(request, delegate)
      assert_not request.reload.decision_authorized_for?(delegate), "決裁の立場が残っている"
      assert_not Request.awaiting_decision_by(delegate).exists?(id: request.id), "承認待ちの一覧に残っている"
      assert_not Request.visible_to(delegate).exists?(id: request.id), "参照できてしまう"
      assert_not request.approvers.exists?(id: delegate.id), "通知の対象に残っている"
    end
end
