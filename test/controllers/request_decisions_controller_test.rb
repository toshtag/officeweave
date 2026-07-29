require "test_helper"

class RequestDecisionsControllerTest < ActionDispatch::IntegrationTest
  test "承認できる利用者は承認できる" do
    sign_in_as users(:taro)

    post request_decision_url(requests(:hanako_expense_pending)), params: { decision: "approve" }

    assert_equal "approved", requests(:hanako_expense_pending).reload.status
  end

  test "差し戻しでコメントを残せる" do
    sign_in_as users(:taro)

    post request_decision_url(requests(:hanako_expense_pending)),
         params: { decision: "return", comment: "領収書を添えてください" }

    request = requests(:hanako_expense_pending).reload

    assert_equal "returned", request.status
    assert_equal "領収書を添えてください", request.request_activities.chronological.last.comment
  end

  test "自分の申請は自分で承認できない" do
    sign_in_as users(:taro)

    post request_decision_url(requests(:taro_leave_pending)), params: { decision: "approve" }

    assert_response :forbidden
    assert_equal "pending", requests(:taro_leave_pending).reload.status
  end

  test "承認する部門に属さない利用者は処理できない" do
    sign_in_as users(:hanako)

    post request_decision_url(requests(:hanako_expense_pending)), params: { decision: "approve" }

    assert_response :forbidden
  end

  test "承認待ちでない申請は処理できない" do
    sign_in_as users(:taro)

    post request_decision_url(requests(:hanako_leave_draft)), params: { decision: "approve" }

    assert_response :forbidden
  end

  test "履歴が申請の画面に並ぶ" do
    sign_in_as users(:hanako)

    get request_url(requests(:hanako_expense_pending))

    assert_select ".timeline__item", minimum: 2
  end
end
