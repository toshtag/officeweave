require "application_system_test_case"

class ResourcesTest < ApplicationSystemTestCase
  test "JavaScript なしで設備・備品を登録し、受付を停止できる" do
    sign_in_as users(:taro)

    visit resources_path
    click_link I18n.t("resources.index.new")

    fill_in Resource.human_attribute_name(:name), with: "会議室 C"
    fill_in Resource.human_attribute_name(:code), with: "room-c"
    fill_in Resource.human_attribute_name(:capacity), with: "12"
    click_button I18n.t("helpers.submit.create")

    assert_text I18n.t("resources.created")
    assert_text "会議室 C"
    assert_text I18n.t("resources.status.reservable")

    click_link I18n.t("common.edit")
    uncheck Resource.human_attribute_name(:reservable)
    click_button I18n.t("helpers.submit.update")

    assert_text I18n.t("resources.status.unavailable")
  end

  test "一般利用者には登録の操作が出ない" do
    sign_in_as users(:hanako)

    visit resources_path

    assert_no_link I18n.t("resources.index.new", locale: :en)
  end
end
