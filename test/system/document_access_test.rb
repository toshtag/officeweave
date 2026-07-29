require "application_system_test_case"

class DocumentAccessSystemTest < ApplicationSystemTestCase
  test "JavaScript なしで参照範囲を部門に限定できる" do
    sign_in_as users(:taro)

    visit new_document_path
    fill_in Document.human_attribute_name(:title), with: "開発部の手引き"
    choose I18n.t("documents.visibilities.departments")
    check departments(:development).display_path
    click_button I18n.t("helpers.submit.create")

    assert_text I18n.t("documents.created")
    assert_text departments(:development).display_path
  end

  test "参照先を指定せずに部門限定にすると理由が示される" do
    sign_in_as users(:taro)

    visit new_document_path
    fill_in Document.human_attribute_name(:title), with: "手引き"
    choose I18n.t("documents.visibilities.departments")
    click_button I18n.t("helpers.submit.create")

    assert_selector ".error-summary"
  end

  test "参照範囲外の文書は一覧に出ない" do
    sign_in_as users(:hanako)

    visit documents_path

    assert_text documents(:travel_rule).title
    assert_no_text documents(:sales_only_document).title
  end
end
