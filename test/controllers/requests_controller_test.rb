require "test_helper"

class RequestsControllerTest < ActionDispatch::IntegrationTest
  test "自分の申請と、承認できる申請だけが並ぶ" do
    sign_in_as users(:hanako)

    get requests_url

    assert_response :success
    assert_select "a", text: requests(:hanako_leave_draft).title
    assert_select "a", text: requests(:taro_leave_pending).title, count: 0
  end

  test "状態で絞り込める" do
    sign_in_as users(:hanako)

    get requests_url(status: "pending")

    assert_select "a", text: requests(:hanako_expense_pending).title
    assert_select "a", text: requests(:hanako_leave_draft).title, count: 0
  end

  test "見えない申請は参照できない" do
    sign_in_as users(:hanako)

    get request_url(requests(:taro_leave_pending))

    assert_response :not_found
  end

  test "申請を作成できる" do
    sign_in_as users(:hanako)

    assert_difference -> { Request.count }, 1 do
      post requests_url, params: {
        request: { request_type_id: request_types(:expense).id, title: "備品の購入", body: "説明" }
      }
    end

    assert_equal "draft", Request.last.status
    assert_equal users(:hanako), Request.last.applicant
  end

  test "承認待ちの申請は申請者でも編集できない" do
    sign_in_as users(:hanako)

    get edit_request_url(requests(:hanako_expense_pending))

    assert_response :forbidden
  end

  test "申請の種別は後から変更できない" do
    sign_in_as users(:hanako)
    request = requests(:hanako_leave_draft)

    patch request_url(request), params: {
      request: { request_type_id: request_types(:expense).id, title: "変更後" }
    }

    assert_equal request_types(:leave), request.reload.request_type
    assert_equal "変更後", request.title
  end
end
