require "application_system_test_case"

class DataTransfersTest < ApplicationSystemTestCase
  test "JavaScript なしで利用者を取り込める" do
    sign_in_as users(:taro)

    visit data_transfers_path
    attach_file I18n.t("data_transfers.import.file"), file_fixture("users.csv")
    click_button I18n.t("data_transfers.import.submit")

    assert_text I18n.t("data_transfers.imported", created: 1, updated: 0)

    visit users_path

    assert_text "鈴木 一郎"
  end

  test "誤りがある場合は取り込まれず、行番号が示される" do
    sign_in_as users(:taro)

    visit data_transfers_path
    attach_file I18n.t("data_transfers.import.file"), file_fixture("users_invalid.csv")
    click_button I18n.t("data_transfers.import.submit")

    assert_selector ".error-summary"
    assert_text I18n.t("data_transfers.import.line", line: 3)
  end
end
