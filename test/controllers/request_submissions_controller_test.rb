require "test_helper"

class RequestSubmissionsControllerTest < ActionDispatch::IntegrationTest
  test "申請者は提出できる" do
    sign_in_as users(:hanako)

    post request_submission_url(requests(:hanako_leave_draft))

    assert_equal "pending", requests(:hanako_leave_draft).reload.status
  end

  test "申請者以外は提出できない" do
    sign_in_as users(:taro)

    post request_submission_url(requests(:hanako_leave_draft))

    assert_response :forbidden
    assert_equal "draft", requests(:hanako_leave_draft).reload.status
  end

  test "承認待ちのものは提出できず、理由が示される" do
    sign_in_as users(:hanako)

    post request_submission_url(requests(:hanako_expense_pending))

    assert_equal I18n.t("requests.cannot_submit", locale: :en), flash[:alert]
  end

  test "申請者は取り下げられる" do
    sign_in_as users(:hanako)

    delete request_submission_url(requests(:hanako_expense_pending))

    assert_equal "withdrawn", requests(:hanako_expense_pending).reload.status
  end

  test "取り下げたものは再び取り下げられない" do
    sign_in_as users(:hanako)
    requests(:hanako_leave_draft).withdraw(actor: users(:hanako))

    delete request_submission_url(requests(:hanako_leave_draft))

    assert_response :forbidden
  end
end
