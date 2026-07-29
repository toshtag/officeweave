require "application_system_test_case"

class AuthorizationSystemTest < ApplicationSystemTestCase
  test "一般利用者には管理者専用の操作が表示されない" do
    sign_in_as users(:hanako)

    visit departments_path
    assert_no_link I18n.t("departments.index.new")

    visit department_path(departments(:sales))
    assert_no_link I18n.t("common.edit")
    assert_no_button I18n.t("common.destroy")
    assert_no_button I18n.t("memberships.remove")
    assert_no_text I18n.t("memberships.new.heading")
  end

  test "管理者には管理者専用の操作が表示される" do
    sign_in_as users(:taro)

    visit departments_path
    assert_link I18n.t("departments.index.new")

    visit department_path(departments(:sales))
    assert_link I18n.t("common.edit")
    assert_button I18n.t("common.destroy")
    assert_text I18n.t("memberships.new.heading")
  end
end
