require "test_helper"

# 申請の画面へ出る承認経路。
# @request は使わない。要求のあとに、その要求の記録で上書きされる。
class ApprovalRouteDisplayTest < ActionDispatch::IntegrationTest
  setup do
    @request_type = request_types(:leave)
    @request_type.approval_steps.create!(position: 20, approver_department: departments(:development))
    # 固定データの下書きを使う。提出からの流れを追う。
    @leave_request = requests(:hanako_leave_draft)
  end

  test "経路と待っている段が出る" do
    @leave_request.submit(actor: users(:hanako))
    # 表示言語が日本語の利用者で見る。花子の設定は英語であり、文面が変わる。
    sign_in_as users(:taro)

    get request_url(@leave_request)

    assert_response :success
    assert_select "dd", text: /#{departments(:sales).name}/
    assert_select "dd", text: /#{departments(:development).name}/
    assert_select "dd", text: /#{I18n.t('requests.awaiting_step')}/
  end

  test "承認した段には承認者が出る" do
    @leave_request.submit(actor: users(:hanako))
    @leave_request.approve(actor: users(:approver))
    # 表示言語が日本語の利用者で見る。花子の設定は英語であり、文面が変わる。
    sign_in_as users(:taro)

    get request_url(@leave_request)

    assert_select "dd", text: /#{I18n.t('requests.approved_by', name: users(:approver).name)}/
  end

  test "種別の段を変えても、提出済みの申請の経路は変わらない" do
    @leave_request.submit(actor: users(:hanako))
    @request_type.approval_steps.first.update!(approver_department: departments(:sales_east))
    # 表示言語が日本語の利用者で見る。花子の設定は英語であり、文面が変わる。
    sign_in_as users(:taro)

    get request_url(@leave_request)

    assert_select "dd", text: /#{departments(:sales).name}/
    assert_select "dd", { text: /#{departments(:sales_east).name}/, count: 0 }
  end
end
