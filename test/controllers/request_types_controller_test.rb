require "test_helper"

class RequestTypesControllerTest < ActionDispatch::IntegrationTest
  test "自組織の申請種別だけが並ぶ" do
    sign_in_as users(:hanako)

    get request_types_url

    assert_response :success
    assert_select "td", text: request_types(:leave).name
    assert_select "td", text: request_types(:other_org_type).name, count: 0
  end

  test "一般利用者は登録できない" do
    sign_in_as users(:hanako)

    assert_no_difference -> { RequestType.count } do
      post request_types_url, params: { request_type: { name: "残業申請", code: "overtime" } }
    end

    assert_response :forbidden
  end

  test "管理者は登録できる" do
    sign_in_as users(:taro)

    assert_difference -> { RequestType.count }, 1 do
      post request_types_url, params: { request_type: { name: "残業申請", code: "overtime" } }
    end
  end

  test "別組織の部門は承認部門に指定できない" do
    sign_in_as users(:taro)

    post request_types_url, params: {
      request_type: {
        name: "残業申請", code: "overtime",
        approval_steps_attributes: { "0" => { position: 10,
                                              approver_department_id: departments(:other_general).id } }
      }
    }

    assert_response :unprocessable_content
  end

  test "登録を監査へ残す" do
    sign_in_as users(:taro)

    assert_difference -> { AuditEvent.where(action: "request_type_created").count }, 1 do
      post request_types_url, params: {
        request_type: {
          name: "残業申請", code: "overtime", description: "残業の理由を書く欄",
          approval_steps_attributes: { "0" => { position: 10,
                                                approver_department_id: departments(:sales).id } }
        }
      }
    end

    event = AuditEvent.where(action: "request_type_created").last

    assert_equal users(:taro), event.actor
    assert_equal "overtime", event.details["code"]
    assert_equal [ departments(:sales).id ], event.details["approver_department_ids"]
  end

  test "変更を監査へ残す" do
    sign_in_as users(:taro)

    assert_difference -> { AuditEvent.where(action: "request_type_updated").count }, 1 do
      patch request_type_url(request_types(:leave)), params: { request_type: { name: "休暇の申請" } }
    end
  end

  test "登録に失敗したときは監査へ残さない" do
    sign_in_as users(:taro)

    assert_no_difference -> { AuditEvent.count } do
      post request_types_url, params: { request_type: { name: "", code: "" } }
    end

    assert_response :unprocessable_content
  end

  test "権限が無い利用者の操作は監査へ残さない" do
    sign_in_as users(:hanako)

    assert_no_difference -> { AuditEvent.count } do
      post request_types_url, params: { request_type: { name: "残業申請", code: "overtime" } }
    end

    assert_response :forbidden
  end

  # 監査の詳細は、誰が経路を変えたかを追うためのものである。
  # 説明の文面をそこへ写すと、監査が文面の履歴になる。
  test "監査の詳細に説明の文面を入れない" do
    sign_in_as users(:taro)

    post request_types_url, params: {
      request_type: { name: "残業申請", code: "overtime", description: "内部だけで使う説明" }
    }

    event = AuditEvent.where(action: "request_type_created").last

    assert_not_includes event.details.values.map(&:to_s).join, "内部だけで使う説明"
  end
end
