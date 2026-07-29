require "application_system_test_case"

class RequestsTest < ApplicationSystemTestCase
  test "JavaScript なしで申請を作成し、提出できる" do
    sign_in_as users(:taro)

    visit requests_path
    click_link I18n.t("requests.index.new")

    select request_types(:expense).name, from: Request.human_attribute_name(:request_type)
    fill_in Request.human_attribute_name(:title), with: "備品の購入"
    fill_in Request.human_attribute_name(:body), with: "作業用の椅子を購入したい。"
    click_button I18n.t("helpers.submit.create")

    assert_text I18n.t("requests.created")
    assert_text I18n.t("requests.statuses.draft")

    click_button I18n.t("requests.submit")

    assert_text I18n.t("requests.submitted")
    assert_text I18n.t("requests.statuses.pending")
  end

  test "提出後は編集できず、取り下げられる" do
    sign_in_as users(:taro)

    visit request_path(requests(:taro_leave_pending))

    assert_no_link I18n.t("common.edit")

    click_button I18n.t("requests.withdraw")

    assert_text I18n.t("requests.withdrawn")
    assert_text I18n.t("requests.statuses.withdrawn")
  end

  test "受付を停止した種別は選べない" do
    sign_in_as users(:taro)

    visit new_request_path

    assert_no_selector "option", text: request_types(:retired_type).name
  end
end
