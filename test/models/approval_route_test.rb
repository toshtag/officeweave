require "test_helper"

# 承認経路の記録。
#
# 提出の時点の段を、申請ごとに写して残す。写さないと、種別の段を後から
# 変えたときに、過去の申請が通った経路が読めなくなる。承認済みの申請でも、
# 表示される経路が今の設定に置き換わる。
class ApprovalRouteTest < ActiveSupport::TestCase
  setup do
    @request_type = request_types(:leave)
    @first = @request_type.approval_steps.first
    @second = @request_type.approval_steps.create!(position: 20, approver_department: departments(:development))
    @second_approver = users(:outsider_free)
    @second_approver.memberships.create!(department: departments(:development))
    @request = @request_type.requests.create!(
      organization: organizations(:main), applicant: users(:hanako), title: "経路を残す申請"
    )
  end

  test "提出で経路を写す" do
    @request.submit(actor: users(:hanako))

    assert_equal [ [ 10, departments(:sales).id ], [ 20, departments(:development).id ] ],
                 @request.request_approval_steps.ordered.map { |step| [ step.position, step.approver_department_id ] }
  end

  test "下書きのうちは経路を持たない" do
    # 提出していない申請は、まだどの経路も通っていない。
    assert_empty @request.request_approval_steps
  end

  test "写した経路は、種別の段を変えても変わらない" do
    @request.submit(actor: users(:hanako))

    @second.destroy!
    @request_type.approval_steps.create!(position: 30, approver_department: departments(:sales_east))

    assert_equal [ 10, 20 ], @request.request_approval_steps.ordered.map(&:position)
  end

  test "写した経路で承認が進む" do
    @request.submit(actor: users(:hanako))
    @second.destroy!

    # 種別から段が消えても、写した経路の 2 段目が残っている。
    assert @request.approve(actor: users(:approver))
    assert_equal "pending", @request.reload.status
    assert_equal 20, @request.current_step_position
  end

  test "承認した段に、承認者と時刻を残す" do
    @request.submit(actor: users(:hanako))
    @request.approve(actor: users(:approver))

    step = @request.request_approval_steps.ordered.first

    assert_equal users(:approver), step.approver
    assert_not_nil step.approved_at
  end

  test "最後の段の承認も記録へ残す" do
    @request.submit(actor: users(:hanako))
    @request.approve(actor: users(:approver))
    @request.approve(actor: @second_approver)

    assert_equal [ users(:approver), @second_approver ],
                 @request.request_approval_steps.ordered.map(&:approver)
  end

  test "差し戻しでも経路は残る" do
    @request.submit(actor: users(:hanako))
    @request.approve(actor: users(:approver))
    @request.return_to_applicant(actor: @second_approver)

    assert_equal 2, @request.reload.request_approval_steps.count
  end

  test "再提出で経路を取り直す" do
    @request.submit(actor: users(:hanako))
    @request.approve(actor: users(:approver))
    @request.return_to_applicant(actor: @second_approver)

    @second.destroy!
    @request.submit(actor: users(:hanako))

    # 取り直した経路は、そのときの段だけになる。承認済みの印も残らない。
    assert_equal [ 10 ], @request.request_approval_steps.reload.ordered.map(&:position)
    assert_nil @request.request_approval_steps.first.approved_at
  end

  test "決裁できる立場は写した経路で判断する" do
    @request.submit(actor: users(:hanako))
    # 種別の 1 段目を別の部門へ変えても、写した経路の担当は変わらない。
    @first.update!(approver_department: departments(:sales_east))

    assert @request.reload.decision_authorized_for?(users(:approver))
  end

  test "経路の記録が無い申請は、種別の段を経路として扱う" do
    # この版より前に提出された申請。写した経路を持たない。
    @request.update!(status: "pending", submitted_at: 1.day.ago, current_step_position: 10)

    assert_equal [ 10, 20 ], @request.route_steps.map(&:position)
    assert @request.decision_authorized_for?(users(:approver))
  end

  test "経路は組織をまたがない" do
    step = @request.request_approval_steps.new(position: 30,
                                               approver_department: organizations(:other).departments.first)

    assert_not step.valid?
  end
end
