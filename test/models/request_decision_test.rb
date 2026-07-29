require "test_helper"

class RequestDecisionTest < ActiveSupport::TestCase
  test "承認できる利用者は承認できる" do
    request = requests(:hanako_leave_draft)
    request.submit(actor: users(:hanako))

    assert request.approve(actor: users(:taro), comment: "確認しました")
    assert_equal "approved", request.reload.status
    assert_not_nil request.decided_at
  end

  test "承認すると記録が残る" do
    request = requests(:hanako_expense_pending)

    assert_difference -> { RequestActivity.count }, 1 do
      request.approve(actor: users(:taro))
    end

    assert_equal "approved", request.request_activities.chronological.last.action
  end

  test "差し戻すと理由を記録できる" do
    request = requests(:hanako_expense_pending)
    request.return_to_applicant(actor: users(:taro), comment: "領収書を添えてください")

    assert_equal "returned", request.reload.status
    assert_equal "領収書を添えてください", request.request_activities.chronological.last.comment
  end

  test "差し戻された申請は再び提出できる" do
    request = requests(:hanako_expense_pending)
    request.return_to_applicant(actor: users(:taro))

    assert request.submit(actor: users(:hanako))
    assert_equal "pending", request.reload.status
  end

  test "自分の申請は自分で承認できない" do
    assert_not requests(:taro_leave_pending).decidable_by?(users(:taro))
  end

  test "承認する部門に属さない利用者は処理できない" do
    assert_not requests(:taro_leave_pending).decidable_by?(users(:hanako))
  end

  test "承認待ちでない申請は処理できない" do
    assert_not requests(:hanako_leave_draft).decidable_by?(users(:taro))
  end

  test "承認済みの申請は再び処理できない" do
    request = requests(:hanako_expense_pending)
    request.approve(actor: users(:taro))

    assert_not request.approve(actor: users(:taro))
  end

  test "状態の変更と記録は一緒に行われる" do
    request = requests(:hanako_leave_draft)

    assert_difference -> { RequestActivity.count }, 1 do
      request.submit(actor: users(:hanako))
    end
  end

  test "許可されていない遷移では記録も残らない" do
    request = requests(:hanako_expense_pending)

    assert_no_difference -> { RequestActivity.count } do
      assert_not request.submit(actor: users(:hanako))
    end
  end
end
