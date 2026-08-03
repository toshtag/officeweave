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

  # 主たる所属かどうかを、はい／いいえで示す。
  #
  # YAML は引用符の無い yes と no を真偽値として読む。鍵が :yes でなくなると
  # 語句を引けず、表示だけが崩れる。例外にならないため、画面を出す側から見る。
  test "所属の一覧が、主たる所属かどうかを示す" do
    # 主たる所属は 1 人につき 1 つである。両方の表示を出すため、
    # 主たるではない所属を足す。
    users(:hanako).memberships.create!(department: departments(:sales), primary: false)

    get department_url(departments(:sales))

    assert_select "td", text: I18n.t("common.yes")
    assert_select "td", text: I18n.t("common.no")
  end

  test "ログインしていない場合は参照できない" do
    sign_out

    get departments_url

    assert_redirected_to new_session_path
  end
end
