require "application_system_test_case"

class LocaleSwitchingTest < ApplicationSystemTestCase
  test "JavaScript なしで表示言語を切り替えられる" do
    visit root_path

    assert_selector "h1", text: I18n.t("home.heading", locale: :ja)

    click_button "English"

    assert_selector "h1", text: I18n.t("home.heading", locale: :en)
    assert_selector "html[lang='en']", visible: :all
  end

  test "現在の言語は選択肢として表示しない" do
    visit root_path

    assert_no_button "日本語"
    assert_button "English"
  end
end
