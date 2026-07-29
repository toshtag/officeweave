require "application_system_test_case"

class RequestDecisionsTest < ApplicationSystemTestCase
  test "JavaScript なしで差し戻し、修正して再提出、承認まで通せる" do
    sign_in_as users(:taro)

    visit request_path(requests(:hanako_expense_pending))
    fill_in I18n.t("request_decisions.comment"), with: "領収書を添えてください"
    click_button I18n.t("request_decisions.return")

    assert_text I18n.t("request_decisions.returnd")
    assert_text I18n.t("requests.statuses.returned")
    assert_text "領収書を添えてください"

    click_button I18n.t("sessions.sign_out")
    sign_in_as users(:hanako)

    visit request_path(requests(:hanako_expense_pending))
    click_button I18n.t("requests.submit", locale: :en)

    assert_text I18n.t("requests.statuses.pending", locale: :en)

    click_button I18n.t("sessions.sign_out", locale: :en)
    sign_in_as users(:taro)

    visit request_path(requests(:hanako_expense_pending))
    click_button I18n.t("request_decisions.approve")

    assert_text I18n.t("request_decisions.approved")
    assert_text I18n.t("requests.statuses.approved")
  end

  test "承認できない利用者には操作が出ない" do
    sign_in_as users(:hanako)

    visit request_path(requests(:hanako_expense_pending))

    assert_no_button I18n.t("request_decisions.approve", locale: :en)
    assert_no_button I18n.t("request_decisions.return", locale: :en)
  end
end
