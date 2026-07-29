require "application_system_test_case"

class NavigationTest < ApplicationSystemTestCase
  test "主要な移動先から各画面へ到達できる" do
    sign_in_as users(:taro)

    within("nav[aria-label='#{I18n.t('navigation.label')}']") do
      click_link I18n.t("departments.index.heading")
    end

    assert_current_path departments_path
  end

  test "現在位置が読み上げにも伝わる" do
    sign_in_as users(:taro)

    visit departments_path

    assert_selector "a[aria-current='page']", text: I18n.t("departments.index.heading")
    assert_no_selector "a[aria-current='page']", text: I18n.t("home.title")
  end

  test "一般利用者には管理者専用の移動先が出ない" do
    sign_in_as users(:hanako)

    assert_no_link I18n.t("users.index.heading", locale: :en)
  end

  test "ログイン前は移動先が表示されない" do
    visit new_session_path

    assert_no_selector "nav[aria-label='#{I18n.t('navigation.label')}']"
  end

  test "ホームに自分の情報と所属が並ぶ" do
    sign_in_as users(:taro)

    assert_text I18n.t("home.profile.heading")
    assert_text users(:taro).name
    assert_text departments(:sales).name
  end
end
