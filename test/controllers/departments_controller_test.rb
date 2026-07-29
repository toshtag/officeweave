require "test_helper"

class DepartmentsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:taro) }

  test "自組織の部門だけが一覧に並ぶ" do
    get departments_url

    assert_response :success
    assert_select "td", text: departments(:sales).code
    assert_select "td", text: departments(:other_general).code, count: 0
  end

  test "別組織の部門は参照できない" do
    get department_url(departments(:other_general))

    assert_response :not_found
  end

  test "部門を作成できる" do
    assert_difference -> { Department.count }, 1 do
      post departments_url, params: { department: { name: "総務部", code: "general" } }
    end

    assert_redirected_to Department.last
    assert_equal organizations(:main), Department.last.organization
  end

  test "識別子が重複する部門は作成できない" do
    assert_no_difference -> { Department.count } do
      post departments_url, params: { department: { name: "別の営業部", code: "sales" } }
    end

    assert_response :unprocessable_content
  end

  test "部門を更新できる" do
    patch department_url(departments(:development)), params: { department: { name: "プロダクト開発部" } }

    assert_redirected_to departments(:development)
    assert_equal "プロダクト開発部", departments(:development).reload.name
  end

  test "下位部門を持つ部門は削除できない" do
    assert_no_difference -> { Department.count } do
      delete department_url(departments(:sales))
    end

    assert_redirected_to departments(:sales)
  end

  test "下位部門を持たない部門は削除できる" do
    assert_difference -> { Department.count }, -1 do
      delete department_url(departments(:development))
    end

    assert_redirected_to departments_path
  end

  test "ログインしていない場合は参照できない" do
    sign_out

    get departments_url

    assert_redirected_to new_session_path
  end
end
