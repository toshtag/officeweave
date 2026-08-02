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

  # 一覧と直接 URL が同じ境界を通ることを、両方から確かめる。
  # 片方だけを確かめると、一覧から外しただけで直接 URL が残る状態を見逃す。
  test "承認担当者の一覧に、他人の提出していない申請は並ばない" do
    sign_in_as users(:approver)

    get requests_url

    assert_response :success
    assert_select "a", text: requests(:taro_leave_pending).title
    assert_select "a", text: requests(:hanako_leave_draft).title, count: 0
  end

  test "承認担当者は、他人の提出していない申請の直接 URL を開けない" do
    sign_in_as users(:approver)

    get request_url(requests(:hanako_leave_draft))

    assert_response :not_found
  end

  test "管理者も、他人の提出していない申請の直接 URL を開けない" do
    sign_in_as users(:taro)

    get request_url(requests(:hanako_leave_draft))

    assert_response :not_found
  end

  test "申請者は、自分の提出していない申請を直接 URL から開ける" do
    sign_in_as users(:hanako)

    get request_url(requests(:hanako_leave_draft))

    assert_response :success
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
