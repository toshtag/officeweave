require "test_helper"

class RequestTest < ActiveSupport::TestCase
  test "申請者は自分の申請を見られる" do
    assert_includes Request.visible_to(users(:hanako)), requests(:hanako_leave_draft)
  end

  test "承認する部門の所属者は、その種別の申請を見られる" do
    assert_includes Request.visible_to(users(:taro)), requests(:hanako_leave_draft)
  end

  test "承認にも申請にも関わらない利用者からは見えない" do
    assert_not_includes Request.visible_to(users(:hanako)), requests(:taro_leave_pending)
  end

  test "管理者はすべての申請を見られる" do
    assert_includes Request.visible_to(users(:taro)), requests(:hanako_expense_pending)
  end

  test "受付を停止した種別では申請できない" do
    request = organizations(:main).requests.new(
      request_type: request_types(:retired_type), applicant: users(:hanako), title: "届出"
    )

    assert_not request.valid?
  end

  test "別組織の種別では申請できない" do
    request = organizations(:main).requests.new(
      request_type: request_types(:other_org_type), applicant: users(:hanako), title: "届出"
    )

    assert_not request.valid?
  end

  test "下書きは提出できる" do
    request = requests(:hanako_leave_draft)

    assert request.submit(actor: users(:hanako))
    assert_equal "pending", request.reload.status
    assert_not_nil request.submitted_at
  end

  test "承認待ちのものは再び提出できない" do
    assert_not requests(:hanako_expense_pending).submit(actor: users(:hanako))
  end

  test "許可されていない状態の移動は受け付けない" do
    request = requests(:hanako_leave_draft)

    assert_not request.can_transition_to?("approved")
    assert request.can_transition_to?("pending")
  end

  test "下書きと差し戻しのものだけ申請者が編集できる" do
    assert requests(:hanako_leave_draft).editable_by?(users(:hanako))
    assert_not requests(:hanako_expense_pending).editable_by?(users(:hanako))
  end

  test "承認できる利用者かどうかを種別が判定する" do
    assert request_types(:leave).approvable_by?(users(:taro))
    assert_not request_types(:leave).approvable_by?(users(:hanako))
    assert request_types(:expense).approvable_by?(users(:taro))
  end
end
