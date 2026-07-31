require "test_helper"

class AuditEventsTest < ActionDispatch::IntegrationTest
  test "ログインが記録される" do
    assert_difference -> { AuditEvent.with_action("signed_in").count }, 1 do
      post session_path, params: { email_address: users(:taro).email_address, password: "password-for-tests" }
    end

    event = AuditEvent.with_action("signed_in").recent_first.first

    assert_equal users(:taro), event.actor
    assert event.ip_address.present?
  end

  test "ログインの失敗も記録される" do
    assert_difference -> { AuditEvent.with_action("sign_in_failed").count }, 1 do
      post session_path, params: { email_address: users(:taro).email_address, password: "wrong-password" }
    end

    assert_nil AuditEvent.with_action("sign_in_failed").first.actor
  end

  test "存在しない利用者での失敗は記録しない" do
    assert_no_difference -> { AuditEvent.count } do
      post session_path, params: { email_address: "nobody@example.com", password: "x" }
    end
  end

  test "利用者の追加が記録される" do
    sign_in_as users(:taro)

    assert_difference -> { AuditEvent.with_action("user_created").count }, 1 do
      post users_url, params: {
        user: { name: "鈴木 一郎", email_address: "ichiro@example.com",
                password: "a-long-secret-value", password_confirmation: "a-long-secret-value" }
      }
    end
  end

  test "部門の削除が記録され、識別子が残る" do
    sign_in_as users(:taro)

    delete department_url(departments(:development))

    event = AuditEvent.with_action("department_deleted").first

    assert_equal departments(:development).code, event.details["code"]
  end

  test "承認が記録される" do
    sign_in_as users(:taro)

    assert_difference -> { AuditEvent.with_action("request_approved").count }, 1 do
      post request_decision_url(requests(:hanako_expense_pending)), params: { decision: "approve" }
    end
  end

  test "管理者は記録を参照できる" do
    sign_in_as users(:taro)

    get audit_events_url

    assert_response :success
  end

  test "一般利用者は記録を参照できない" do
    sign_in_as users(:hanako)

    get audit_events_url

    assert_response :forbidden
  end

  test "自組織の記録だけが並ぶ" do
    AuditEvent.record(organization: organizations(:other), action: "signed_in", actor: users(:outsider))

    sign_in_as users(:taro)

    get audit_events_url

    assert_select "td", text: users(:outsider).name, count: 0
  end
end
