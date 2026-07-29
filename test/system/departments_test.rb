require "application_system_test_case"

class DepartmentsTest < ApplicationSystemTestCase
  setup { sign_in_as users(:taro) }

  test "JavaScript なしで部門を追加し、所属者を管理できる" do
    visit departments_path
    click_link I18n.t("departments.index.new")

    fill_in Department.human_attribute_name(:name), with: "総務部"
    fill_in Department.human_attribute_name(:code), with: "general"
    click_button I18n.t("helpers.submit.create")

    assert_text I18n.t("departments.created")
    assert_text "総務部"

    select users(:hanako).name, from: User.model_name.human
    click_button I18n.t("memberships.new.submit")

    assert_text I18n.t("memberships.created")
    assert_text users(:hanako).name

    click_button I18n.t("memberships.remove")

    assert_text I18n.t("memberships.destroyed")
    assert_text I18n.t("departments.show.no_members")
  end

  test "入力に誤りがあると理由が示される" do
    visit new_department_path

    fill_in Department.human_attribute_name(:name), with: "別の営業部"
    fill_in Department.human_attribute_name(:code), with: "sales"
    click_button I18n.t("helpers.submit.create")

    assert_selector ".error-summary"
  end

  test "上位部門を含めた位置づけが示される" do
    visit department_path(departments(:sales_east))

    assert_text "営業部 / 営業部 東日本課"
  end
end
