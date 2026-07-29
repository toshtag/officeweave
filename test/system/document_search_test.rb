require "application_system_test_case"

class DocumentSearchSystemTest < ApplicationSystemTestCase
  setup { sign_in_as users(:taro) }

  test "JavaScript なしで日本語の語句を検索できる" do
    visit documents_path

    fill_in I18n.t("documents.index.query"), with: "旅費"
    click_button I18n.t("documents.index.search")

    assert_text documents(:travel_rule).title
    assert_no_text documents(:onboarding).title
  end

  test "条件を消して一覧へ戻れる" do
    visit documents_path(query: "旅費")

    click_link I18n.t("documents.index.clear")

    assert_text documents(:travel_rule).title
    assert_text documents(:onboarding).title
  end
end
