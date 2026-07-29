require "application_system_test_case"

class SettingsTest < ApplicationSystemTestCase
  test "JavaScript なしで受け取る通知と表示言語を変更できる" do
    sign_in_as users(:taro)

    click_link I18n.t("settings.heading")

    uncheck I18n.t("settings.events.announcement_published")
    select I18n.t("locale_switcher.names.en"), from: User.human_attribute_name(:locale)
    click_button I18n.t("settings.submit")

    assert_text I18n.t("settings.updated", locale: :en)
    assert_no_checked_field I18n.t("settings.events.announcement_published", locale: :en)
  end
end
