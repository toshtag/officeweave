require "test_helper"

class RequestTest < ActiveSupport::TestCase
  test "申請者は自分の申請を見られる" do
    assert_includes Request.visible_to(users(:hanako)), requests(:hanako_leave_draft)
  end

  test "申請者は提出していない自分の申請も見られる" do
    assert_nil requests(:hanako_leave_draft).submitted_at
    assert_includes Request.visible_to(users(:hanako)), requests(:hanako_leave_draft)
  end

  test "承認する部門の所属者は、その種別の提出済みの申請を見られる" do
    assert_includes Request.visible_to(users(:approver)), requests(:taro_leave_pending)
  end

  test "承認にも申請にも関わらない利用者からは見えない" do
    assert_not_includes Request.visible_to(users(:hanako)), requests(:taro_leave_pending)
  end

  test "管理者は提出済みの申請をすべて見られる" do
    assert_includes Request.visible_to(users(:taro)), requests(:hanako_expense_pending)
  end

  # 下書きは申請者が提出前に書いているものであり、承認担当者へ渡す操作は提出である。
  # 提出していない内容を、その操作より前から見せない。
  test "承認担当者は、他人の提出していない申請を見られない" do
    assert_not_includes Request.visible_to(users(:approver)), requests(:hanako_leave_draft)
  end

  test "管理者も、他人の提出していない申請を見られない" do
    assert_not_includes Request.visible_to(users(:taro)), requests(:hanako_leave_draft)
  end

  # 提出の有無は status では判断できない。差し戻しと取り下げは、
  # 提出を経た場合と経ていない場合の両方があり、status は同じになる。
  test "差し戻された申請は、承認担当者から見える" do
    assert_includes Request.visible_to(users(:approver)), requests(:hanako_leave_returned)
  end

  test "提出後に取り下げた申請は、承認担当者から見える" do
    assert_includes Request.visible_to(users(:approver)), requests(:hanako_leave_withdrawn_after_submit)
  end

  test "提出せずに取り下げた申請は、承認担当者から見えない" do
    withdrawn = requests(:hanako_leave_withdrawn_before_submit)

    assert_equal "withdrawn", withdrawn.status
    assert_nil withdrawn.submitted_at
    assert_not_includes Request.visible_to(users(:approver)), withdrawn
  end

  test "提出すると、承認担当者から見えるようになる" do
    draft = requests(:hanako_leave_draft)

    assert_not_includes Request.visible_to(users(:approver)), draft
    draft.submit(actor: users(:hanako))

    assert_includes Request.visible_to(users(:approver)), draft
  end

  # 処理待ちは pending だけを対象にしており、提出していない申請は元から含まれない。
  # 参照範囲を狭めても、担当者の処理待ち件数は変わらない。
  test "処理待ちの対象は変わらない" do
    awaiting = Request.awaiting_decision_by(users(:approver))

    assert_includes awaiting, requests(:taro_leave_pending)
    assert_not_includes awaiting, requests(:hanako_leave_draft)
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
