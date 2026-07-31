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

  # 立場のない利用者と、立場はあるが状態が変わっていた場合とを分けて扱う。
  # 前者は表示そのものを拒み、後者は操作の失敗として理由を返す。
  test "承認待ちでない申請は処理できず、理由が示される" do
    sign_in_as users(:taro)

    post request_decision_url(requests(:hanako_leave_draft)), params: { decision: "approve" }

    assert_redirected_to requests(:hanako_leave_draft)
    assert_equal I18n.t("request_decisions.failed"), flash[:alert]
    assert_equal "draft", requests(:hanako_leave_draft).reload.status
  end

  test "承認待ちでない申請では履歴も通知も監査も残らない" do
    sign_in_as users(:taro)

    assert_no_difference [ -> { RequestActivity.count }, -> { Notification.count }, -> { AuditEvent.count } ] do
      post request_decision_url(requests(:hanako_leave_draft)), params: { decision: "approve" }
    end
  end

  test "承認する部門に属さない利用者では履歴も通知も監査も残らない" do
    sign_in_as users(:hanako)

    assert_no_difference [ -> { RequestActivity.count }, -> { Notification.count }, -> { AuditEvent.count } ] do
      post request_decision_url(requests(:hanako_expense_pending)), params: { decision: "approve" }
    end
  end

  test "履歴が申請の画面に並ぶ" do
    sign_in_as users(:hanako)

    get request_url(requests(:hanako_expense_pending))

    assert_select ".timeline__item", minimum: 2
  end
end
