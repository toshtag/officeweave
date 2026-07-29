require "application_system_test_case"

class DocumentAttachmentsSystemTest < ApplicationSystemTestCase
  test "JavaScript なしでファイルを添付し、取り除ける" do
    sign_in_as users(:taro)

    visit new_document_path
    fill_in Document.human_attribute_name(:title), with: "設備の使い方"
    attach_file Document.human_attribute_name(:attachments), file_fixture("sample.txt")
    click_button I18n.t("helpers.submit.create")

    assert_text I18n.t("documents.created")
    assert_text "sample.txt"

    click_link I18n.t("common.edit")
    check "sample.txt"
    click_button I18n.t("helpers.submit.update")

    assert_no_text "sample.txt"
  end
end
