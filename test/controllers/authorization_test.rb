require "test_helper"

class AuthorizationTest < ActionDispatch::IntegrationTest
  test "一般利用者は部門を参照できる" do
    sign_in_as users(:hanako)

    get departments_url
    assert_response :success

    get department_url(departments(:sales))
    assert_response :success
  end

  test "一般利用者は部門を追加できない" do
    sign_in_as users(:hanako)

    assert_no_difference -> { Department.count } do
      post departments_url, params: { department: { name: "総務部", code: "general" } }
    end

    assert_response :forbidden
  end

  test "一般利用者は部門の編集画面へ入れない" do
    sign_in_as users(:hanako)

    get edit_department_url(departments(:sales))

    assert_response :forbidden
  end

  test "一般利用者は部門を削除できない" do
    sign_in_as users(:hanako)

    assert_no_difference -> { Department.count } do
      delete department_url(departments(:development))
    end

    assert_response :forbidden
  end

  test "一般利用者は所属を変更できない" do
    sign_in_as users(:hanako)

    assert_no_difference -> { Membership.count } do
      post department_memberships_url(departments(:development)),
           params: { membership: { user_id: users(:hanako).id } }
    end

    assert_response :forbidden

    assert_no_difference -> { Membership.count } do
      delete department_membership_url(departments(:sales), memberships(:taro_sales))
    end

    assert_response :forbidden
  end

  test "管理者は部門を追加できる" do
    sign_in_as users(:taro)

    assert_difference -> { Department.count }, 1 do
      post departments_url, params: { department: { name: "総務部", code: "general" } }
    end
  end

  test "権限が足りない場合は、利用者の言語で理由が示される" do
    sign_in_as users(:hanako)

    get edit_department_url(departments(:sales))

    # hanako は表示言語を英語に設定している。
    assert_select "h1", I18n.t("errors.forbidden.heading", locale: :en)
  end
end
