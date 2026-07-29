require "test_helper"

class RequestScopesTest < ActionDispatch::IntegrationTest
  test "自分の担当は、処理を待たれている申請だけになる" do
    awaiting = Request.awaiting_decision_by(users(:taro))

    assert_includes awaiting, requests(:hanako_expense_pending)
    assert_not_includes awaiting, requests(:taro_leave_pending)
    assert_not_includes awaiting, requests(:hanako_leave_draft)
  end

  test "承認する部門に属さない利用者の担当は空になる" do
    assert_empty Request.awaiting_decision_by(users(:hanako))
  end

  test "一覧を自分の申請に絞り込める" do
    sign_in_as users(:hanako)

    get requests_url(scope: "mine")

    assert_select "a", text: requests(:hanako_leave_draft).title
    assert_select "a", text: requests(:hanako_expense_pending).title
  end

  test "一覧を自分の担当に絞り込める" do
    sign_in_as users(:taro)

    get requests_url(scope: "awaiting")

    assert_select "a", text: requests(:hanako_expense_pending).title
    assert_select "a", text: requests(:taro_leave_pending).title, count: 0
  end

  test "対象と状態を同時に絞り込める" do
    sign_in_as users(:hanako)

    get requests_url(scope: "mine", status: "draft")

    assert_select "a", text: requests(:hanako_leave_draft).title
    assert_select "a", text: requests(:hanako_expense_pending).title, count: 0
  end

  test "知らない対象の指定は無視して全体を表示する" do
    sign_in_as users(:taro)

    get requests_url(scope: "everything")

    assert_response :success
    assert_select "a", text: requests(:taro_leave_pending).title
  end

  test "ホームに担当分と進行中の申請が並ぶ" do
    sign_in_as users(:taro)

    get root_url

    assert_select "#home-requests"
    assert_select "a", text: requests(:hanako_expense_pending).title
    assert_select "a", text: requests(:taro_leave_pending).title
  end
end
