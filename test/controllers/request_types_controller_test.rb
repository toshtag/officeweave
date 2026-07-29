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
      request_type: { name: "残業申請", code: "overtime", approver_department_id: departments(:other_general).id }
    }

    assert_response :unprocessable_content
  end
end
