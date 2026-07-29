require "application_system_test_case"

class RequestScopesSystemTest < ApplicationSystemTestCase
  test "対象を切り替えて申請を絞り込める" do
    sign_in_as users(:taro)

    visit requests_path
    assert_text requests(:hanako_expense_pending).title
    assert_text requests(:taro_leave_pending).title

    click_link I18n.t("requests.index.scopes.mine")

    assert_text requests(:taro_leave_pending).title
    assert_no_text requests(:hanako_expense_pending).title

    click_link I18n.t("requests.index.scopes.awaiting", count: 1)

    assert_text requests(:hanako_expense_pending).title
    assert_no_text requests(:taro_leave_pending).title
  end

  test "現在の対象が読み上げにも伝わる" do
    sign_in_as users(:taro)

    visit requests_path(scope: "mine")

    assert_selector "a[aria-current='page']", text: I18n.t("requests.index.scopes.mine")
  end
end
