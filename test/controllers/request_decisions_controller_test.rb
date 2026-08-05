require "test_helper"

class RequestDecisionsControllerTest < ActionDispatch::IntegrationTest
  # 段ごとに違う担当を置いた 3 段の経路。
  #
  # 単段では、途中の段という状態そのものが作れない。担当を分けないと、
  # 段が進んだかどうかが担当の違いに現れない。
  FIRST_STEP = 10
  SECOND_STEP = 20
  LAST_STEP = 30

  test "承認できる利用者は承認できる" do
    sign_in_as users(:taro)

    post request_decision_url(requests(:hanako_expense_pending)),
         params: { decision: "approve", expected_step_position: FIRST_STEP }

    assert_equal "approved", requests(:hanako_expense_pending).reload.status
  end

  test "途中の段を承認しても応答が失敗しない" do
    request = three_step_request
    sign_in_as users(:approver)

    post request_decision_url(request), params: { decision: "approve", expected_step_position: FIRST_STEP }

    assert_redirected_to request
    assert_equal "pending", request.reload.status
    assert_equal SECOND_STEP, request.current_step_position
  end

  # 状態から監査の種別を組み立てると、承認済みへ至らない承認で
  # 許可されていない値が生まれる。
  test "途中の段の承認も承認として監査へ残る" do
    request = three_step_request
    sign_in_as users(:approver)

    assert_difference -> { AuditEvent.count }, 1 do
      post request_decision_url(request), params: { decision: "approve", expected_step_position: FIRST_STEP }
    end

    assert_equal "request_approved", AuditEvent.order(:id).last.action
  end

  test "進んだあとの段を指さない決裁は競合として拒む" do
    request = three_step_request
    approve_first_step(request)

    sign_in_as users(:taro)
    post request_decision_url(request), params: { decision: "approve", expected_step_position: FIRST_STEP }

    assert_response :conflict
    assert_equal SECOND_STEP, request.reload.current_step_position
  end

  test "期待する段を送らない決裁は競合として拒む" do
    request = three_step_request
    sign_in_as users(:approver)

    post request_decision_url(request), params: { decision: "approve" }

    assert_response :conflict
    assert_equal FIRST_STEP, request.reload.current_step_position
  end

  # 段が進んだあとは、進む前の段の担当であっても決裁できない。
  test "進んだあとの段の担当でない利用者は決裁できない" do
    request = three_step_request
    approve_first_step(request)

    sign_in_as users(:approver)
    post request_decision_url(request), params: { decision: "approve", expected_step_position: SECOND_STEP }

    assert_response :forbidden
    assert_equal SECOND_STEP, request.reload.current_step_position
  end

  test "拒まれた決裁は段も履歴も監査も通知も変えない" do
    request = three_step_request
    approve_first_step(request)

    sign_in_as users(:approver)

    assert_no_difference [ -> { RequestActivity.count }, -> { Notification.count }, -> { AuditEvent.count },
                           -> { RequestApprovalStep.approved.count } ] do
      post request_decision_url(request), params: { decision: "approve", expected_step_position: SECOND_STEP }
    end

    assert_equal SECOND_STEP, request.reload.current_step_position
  end

  test "最後の段の承認で承認済みになる" do
    request = three_step_request
    approve_first_step(request)
    approve_step(request, actor: users(:outsider_free))

    sign_in_as users(:taro)
    post request_decision_url(request), params: { decision: "approve", expected_step_position: LAST_STEP }

    assert_redirected_to request
    assert_equal "approved", request.reload.status
  end

  test "差し戻しでコメントを残せる" do
    sign_in_as users(:taro)

    post request_decision_url(requests(:hanako_expense_pending)),
         params: { decision: "return", comment: "領収書を添えてください", expected_step_position: FIRST_STEP }

    request = requests(:hanako_expense_pending).reload

    assert_equal "returned", request.status
    assert_equal "領収書を添えてください", request.request_activities.chronological.last.comment
  end

  # 綴りの誤ったキーが残っていると、正しい綴りを足した担当者の追加が
  # 参照されないまま増える。
  test "差し戻しの知らせは正しい綴りのキーを引く" do
    sign_in_as users(:taro)

    post request_decision_url(requests(:hanako_expense_pending)),
         params: { decision: "return", expected_step_position: FIRST_STEP }

    assert_equal I18n.t("request_decisions.returned"), flash[:notice]
  end

  test "綴りの誤ったキーを残さない" do
    I18n.available_locales.each do |locale|
      assert_not I18n.exists?("request_decisions.returnd", locale),
                 "#{locale} に returnd が残っています"
    end
  end

  # キーを要求の値から組み立てると、想定外の値がそのまま翻訳キーになる。
  test "想定外の決裁では翻訳キーを組み立てない" do
    sign_in_as users(:taro)

    post request_decision_url(requests(:hanako_expense_pending)),
         params: { decision: "returnd", expected_step_position: FIRST_STEP }

    assert_equal I18n.t("request_decisions.failed"), flash[:alert]
    assert_equal "pending", requests(:hanako_expense_pending).reload.status
  end

  test "自分の申請は自分で承認できない" do
    sign_in_as users(:taro)

    post request_decision_url(requests(:taro_leave_pending)),
         params: { decision: "approve", expected_step_position: FIRST_STEP }

    assert_response :forbidden
    assert_equal "pending", requests(:taro_leave_pending).reload.status
  end

  test "承認する部門に属さない利用者は処理できない" do
    sign_in_as users(:hanako)

    post request_decision_url(requests(:hanako_expense_pending)),
         params: { decision: "approve", expected_step_position: FIRST_STEP }

    assert_response :forbidden
  end

  # 立場のない利用者と、立場はあるが状態が変わっていた場合とを分けて扱う。
  # 前者は表示そのものを拒み、後者は操作の失敗として理由を返す。
  #
  # 対象は提出済みで承認待ちでないものとする。提出していない申請は参照範囲の
  # 外にあり、状態を確かめる前に見つからない扱いになる。
  test "承認待ちでない申請は処理できず、理由が示される" do
    sign_in_as users(:taro)

    post request_decision_url(requests(:hanako_leave_returned)),
         params: { decision: "approve", expected_step_position: FIRST_STEP }

    assert_redirected_to requests(:hanako_leave_returned)
    assert_equal I18n.t("request_decisions.failed"), flash[:alert]
    assert_equal "returned", requests(:hanako_leave_returned).reload.status
  end

  test "承認待ちでない申請では履歴も通知も監査も残らない" do
    sign_in_as users(:taro)

    assert_no_difference [ -> { RequestActivity.count }, -> { Notification.count }, -> { AuditEvent.count } ] do
      post request_decision_url(requests(:hanako_leave_returned)),
           params: { decision: "approve", expected_step_position: FIRST_STEP }
    end
  end

  # 参照できないものは、立場の判定より前に見つからない扱いにする。
  # 立場を先に判定すると、403 と 404 の違いから存在が分かる。
  test "提出していない申請は、決裁の経路からも見つからない" do
    sign_in_as users(:taro)

    post request_decision_url(requests(:hanako_leave_draft)),
         params: { decision: "approve", expected_step_position: FIRST_STEP }

    assert_response :not_found
    assert_equal "draft", requests(:hanako_leave_draft).reload.status
  end

  test "承認する部門に属さない利用者では履歴も通知も監査も残らない" do
    sign_in_as users(:hanako)

    assert_no_difference [ -> { RequestActivity.count }, -> { Notification.count }, -> { AuditEvent.count } ] do
      post request_decision_url(requests(:hanako_expense_pending)),
           params: { decision: "approve", expected_step_position: FIRST_STEP }
    end
  end

  test "履歴が申請の画面に並ぶ" do
    sign_in_as users(:hanako)

    get request_url(requests(:hanako_expense_pending))

    assert_select ".timeline__item", minimum: 2
  end

  private
    # 段ごとに担当を分けた 3 段の申請を、提出済みの状態で作る。
    #
    # 3 段目は部門を指定しない。管理者が担当する段を 1 つ置くことで、
    # すべての段を担当する利用者の二重送信も同じ経路で確かめられる。
    def three_step_request
      users(:outsider_free).memberships.create!(department: departments(:development))

      request_type = RequestType.create!(
        organization: organizations(:main), name: "多段の申請", code: "multi-step", position: 30,
        approval_steps_attributes: [
          { position: FIRST_STEP, approver_department_id: departments(:sales).id },
          { position: SECOND_STEP, approver_department_id: departments(:development).id },
          { position: LAST_STEP, approver_department_id: nil }
        ]
      )

      request = request_type.requests.create!(
        organization: organizations(:main), applicant: users(:hanako), title: "多段の申請"
      )
      request.submit(actor: users(:hanako))
      request
    end

    def approve_first_step(request)
      approve_step(request, actor: users(:approver))
    end

    # 直前の段を通しておく。画面を経由すると、確かめたい段以外の応答まで
    # このテストの前提に入る。
    def approve_step(request, actor:)
      request.approve(actor: actor)
    end
end
