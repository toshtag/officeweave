require "test_helper"

# 多段の承認。
#
# 段をすべて通ったときにだけ承認済みになる。途中の段の承認では、次の段の
# 担当を待つ状態が続く。差し戻しは、どの段からでも申請者へ戻す。
#
# 進行中の申請の意味を変えない。単段の種別は、これまでと同じ動きになる。
class MultiStepApprovalTest < ActiveSupport::TestCase
  setup do
    @request_type = request_types(:leave)
    @first = @request_type.approval_steps.first
    # 2 段目は 1 段目と別の部門とする。同じ部門にすると、段を進めたかどうかが
    # 担当の違いに現れない。
    @second = @request_type.approval_steps.create!(position: 20, approver_department: departments(:development))
    @second_approver = users(:outsider_free)
    @second_approver.memberships.create!(department: departments(:development))
    @request = @request_type.requests.create!(
      organization: organizations(:main), applicant: users(:hanako), title: "多段の申請"
    )
  end

  test "提出すると 1 段目を待つ" do
    @request.submit(actor: users(:hanako))

    assert_equal "pending", @request.status
    assert_equal @first.position, @request.current_step_position
    assert_equal @first, @request.current_step
  end

  test "1 段目の承認では承認済みにならない" do
    @request.submit(actor: users(:hanako))

    assert @request.approve(actor: users(:approver))

    assert_equal "pending", @request.reload.status
    assert_equal @second.position, @request.current_step_position
  end

  test "最後の段の承認で承認済みになる" do
    @request.submit(actor: users(:hanako))
    @request.approve(actor: users(:approver))

    assert @request.approve(actor: @second_approver)

    assert_equal "approved", @request.reload.status
    assert_not_nil @request.decided_at
  end

  test "次の段の担当でなければ承認できない" do
    @request.submit(actor: users(:hanako))
    @request.approve(actor: users(:approver))

    # 2 段目は開発部が担当する。1 段目の担当は次の段を承認できない。
    refute @request.reload.decision_authorized_for?(users(:approver))
  end

  test "先の段の担当は、まだ承認できない" do
    @request.submit(actor: users(:hanako))

    # 1 段目は営業部が担当する。2 段目の担当は、まだ決裁できない。
    refute @request.decision_authorized_for?(@second_approver)
  end

  test "段ごとの承認を記録へ残す" do
    @request.submit(actor: users(:hanako))
    @request.approve(actor: users(:approver))

    activity = @request.request_activities.where(action: "approved").last

    assert_equal users(:approver), activity.actor
    # どの段の承認かが分からないと、履歴から経路を追えない。
    assert_equal @first.position, activity.step_position
  end

  test "差し戻しは途中の段からでも申請者へ戻す" do
    @request.submit(actor: users(:hanako))
    @request.approve(actor: users(:approver))

    assert @request.return_to_applicant(actor: @second_approver)

    assert_equal "returned", @request.reload.status
  end

  test "差し戻したあとの再提出は 1 段目から始める" do
    @request.submit(actor: users(:hanako))
    @request.approve(actor: users(:approver))
    @request.return_to_applicant(actor: @second_approver)

    @request.submit(actor: users(:hanako))

    assert_equal @first.position, @request.reload.current_step_position
  end

  test "承認を待つ利用者は、現在の段の担当だけとする" do
    @request.submit(actor: users(:hanako))

    assert_includes Request.awaiting_decision_by(users(:approver)), @request

    @request.approve(actor: users(:approver))

    refute_includes Request.awaiting_decision_by(users(:approver)).reload, @request
    assert_includes Request.awaiting_decision_by(@second_approver), @request
  end

  test "通知は現在の段の担当へ送る" do
    @request.submit(actor: users(:hanako))

    assert_includes @request.approvers, users(:approver)
    refute_includes @request.approvers, @second_approver
  end

  test "段を進めると、次の段の担当へ知らせる" do
    @request.submit(actor: users(:hanako))

    assert_difference -> { Notification.where(user: @second_approver, event: "request_submitted").count }, 1 do
      @request.approve(actor: users(:approver))
    end
  end

  test "最後の段の承認では、次の段の担当へ知らせない" do
    @request.submit(actor: users(:hanako))
    @request.approve(actor: users(:approver))

    assert_no_difference -> { Notification.where(event: "request_submitted").count } do
      @request.approve(actor: @second_approver)
    end
  end

  test "単段の種別はこれまでと同じ動きになる" do
    @second.destroy!
    single = @request_type.requests.create!(
      organization: organizations(:main), applicant: users(:hanako), title: "単段の申請"
    )
    single.submit(actor: users(:hanako))

    assert single.approve(actor: users(:approver))
    assert_equal "approved", single.reload.status
  end

  test "段を消しても、進行中の申請は止まらない" do
    @request.submit(actor: users(:hanako))
    @second.destroy!

    # 1 段目を承認した時点で、次の段は無い。承認済みへ進める。
    assert @request.approve(actor: users(:approver))
    assert_equal "approved", @request.reload.status
  end

  test "段を足しても、進行中の申請の現在の段は変わらない" do
    @request.submit(actor: users(:hanako))
    @request_type.approval_steps.create!(position: 5, approver_department: departments(:sales_east))

    # 前へ段を足しても、待っている段は動かない。
    assert_equal @first.position, @request.reload.current_step_position
  end
end
