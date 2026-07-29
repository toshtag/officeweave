require "application_system_test_case"

class DocumentsTest < ApplicationSystemTestCase
  test "JavaScript なしで分類を登録し、文書を作成して絞り込める" do
    sign_in_as users(:taro)

    visit documents_path
    click_link I18n.t("document_categories.index.heading")
    click_link I18n.t("document_categories.index.new")

    fill_in DocumentCategory.human_attribute_name(:name), with: "議事録"
    fill_in DocumentCategory.human_attribute_name(:code), with: "minutes"
    click_button I18n.t("helpers.submit.create")

    assert_text I18n.t("document_categories.created")

    visit new_document_path
    fill_in Document.human_attribute_name(:title), with: "定例会議の記録"
    select "議事録", from: Document.human_attribute_name(:document_category)
    fill_in Document.human_attribute_name(:body), with: "本日の議題。"
    click_button I18n.t("helpers.submit.create")

    assert_text I18n.t("documents.created")

    visit documents_path
    select "議事録", from: Document.human_attribute_name(:document_category)
    click_button I18n.t("events.index.filter")

    assert_text "定例会議の記録"
    assert_no_text documents(:travel_rule).title
  end

  test "一般利用者には分類の管理が出ない" do
    sign_in_as users(:hanako)

    visit documents_path

    assert_no_link I18n.t("document_categories.index.heading", locale: :en)
  end
end
