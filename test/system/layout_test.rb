require "application_system_test_case"

class LayoutTest < ApplicationSystemTestCase
  setup { sign_in_as users(:taro) }

  test "見出し領域、本文領域、脚注領域がある" do
    visit root_path

    assert_selector "header.page__header"
    assert_selector "main.page__main"
    assert_selector "footer.page__footer"
  end

  test "製品名から入口の画面へ戻れる" do
    visit root_path

    click_link I18n.t("application.name")

    assert_current_path root_path
  end
end
