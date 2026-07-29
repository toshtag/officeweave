require "application_system_test_case"

class AccessibilityTest < ApplicationSystemTestCase
  test "本文へ移動する読み飛ばし用リンクがある" do
    visit root_path

    skip_link = find(".skip-link", visible: :all)

    assert_equal I18n.t("application.skip_to_content"), skip_link.text
    assert_equal "#main", skip_link[:href]
    assert_selector "main#main", visible: :all
  end

  test "地標が一組ずつ存在する" do
    visit root_path

    assert_selector "header[role='banner']", count: 1, visible: :all
    assert_selector "main", count: 1, visible: :all
    assert_selector "footer[role='contentinfo']", count: 1, visible: :all
  end

  test "見出しが 1 つだけある" do
    visit root_path

    assert_selector "h1", count: 1
  end

  test "文書の言語が示されている" do
    visit root_path

    assert_selector "html[lang='ja']", visible: :all
  end

  test "言語の切り替えに説明が付いている" do
    visit root_path

    assert_selector ".locale-switcher__group[role='group'][aria-labelledby='locale-switcher-label']", visible: :all
    assert_selector "#locale-switcher-label", visible: :all
    expected = I18n.t("locale_switcher.switch_to", language: I18n.t("locale_switcher.names.en"))
    assert_selector "button[aria-label='#{expected}']"
  end

  test "選択中の言語が示されている" do
    visit root_path

    assert_selector ".locale-switcher__current[aria-current='true']", text: I18n.t("locale_switcher.names.ja")
  end
end
