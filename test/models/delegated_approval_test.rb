require "test_helper"

# 代理での決裁。
#
# 委任を受けた利用者は、委任した利用者が担当する段を決裁できる。
# 決裁の記録には、誰の代わりに決裁したかを残す。
class DelegatedApprovalTest < ActiveSupport::TestCase
  setup do
    @request_type = request_types(:leave)
    @approver = users(:approver)
    @delegate = users(:outsider_free)
    @leave_request = requests(:hanako_leave_draft)
    @leave_request.submit(actor: users(:hanako))
  end

  test "委任を受けた利用者は決裁できる" do
    delegate!

    assert @leave_request.decision_authorized_for?(@delegate)
  end

  test "委任が無ければ決裁できない" do
    refute @leave_request.decision_authorized_for?(@delegate)
  end

  test "期間の外の委任では決裁できない" do
    delegate!(starts_on: Date.current + 1)

    refute @leave_request.decision_authorized_for?(@delegate)
  end

  test "代理で承認できる" do
    delegate!

    assert @leave_request.approve(actor: @delegate)
    assert_equal "approved", @leave_request.reload.status
  end

  test "代理で差し戻せる" do
    delegate!

    assert @leave_request.return_to_applicant(actor: @delegate)
    assert_equal "returned", @leave_request.reload.status
  end

  test "誰の代わりに決裁したかを記録へ残す" do
    delegate!

    @leave_request.approve(actor: @delegate)
    activity = @leave_request.request_activities.where(action: "approved").last

    assert_equal @delegate, activity.actor
    assert_equal @approver, activity.on_behalf_of
  end

  test "自分が担当する決裁では代わりの相手を残さない" do
    @leave_request.approve(actor: @approver)
    activity = @leave_request.request_activities.where(action: "approved").last

    assert_nil activity.on_behalf_of
  end

  test "写した経路の承認者は、実際に決裁した利用者とする" do
    delegate!

    @leave_request.approve(actor: @delegate)
    step = @leave_request.request_approval_steps.ordered.first

    # 誰が判断したかを残す。代わりに決裁した相手は履歴から辿る。
    assert_equal @delegate, step.approver
  end

  test "承認待ちの一覧に出る" do
    delegate!

    assert_includes Request.awaiting_decision_by(@delegate), @leave_request
  end

  test "委任が終われば一覧から消える" do
    delegate!(starts_on: Date.current - 5, ends_on: Date.current - 1)

    refute_includes Request.awaiting_decision_by(@delegate), @leave_request
  end

  test "自分の申請は代理でも決裁できない" do
    own = requests(:hanako_expense_pending)
    ApprovalDelegation.create!(organization: organizations(:main), delegator: users(:taro),
                               delegate: own.applicant, starts_on: Date.current)

    refute own.decision_authorized_for?(own.applicant)
  end

  test "提出の知らせは委任を受けた利用者へも届く" do
    delegate!
    another = requests(:hanako_leave_returned)

    assert_difference -> { Notification.where(user: @delegate, event: "request_submitted").count }, 1 do
      another.submit(actor: users(:hanako))
    end
  end

  private
    def delegate!(starts_on: Date.current, ends_on: nil)
      ApprovalDelegation.create!(organization: organizations(:main), delegator: @approver,
                                 delegate: @delegate, starts_on: starts_on, ends_on: ends_on)
    end
end
