require "application_system_test_case"

class UsersTest < ApplicationSystemTestCase
  setup { sign_in_as users(:taro) }

  test "JavaScript なしで利用者を追加し、無効化して再び有効にできる" do
    visit users_path
    click_link I18n.t("users.index.new")

    fill_in User.human_attribute_name(:name), with: "鈴木 一郎"
    fill_in User.human_attribute_name(:email_address), with: "ichiro@example.com"
    fill_in User.human_attribute_name(:password), with: "a-secret-value"
    fill_in User.human_attribute_name(:password_confirmation), with: "a-secret-value"
    click_button I18n.t("helpers.submit.create")

    assert_text I18n.t("users.created")
    assert_text "鈴木 一郎"

    within("tr", text: "鈴木 一郎") { click_button I18n.t("users.deactivate") }

    assert_text I18n.t("users.deactivated")
    assert_text I18n.t("users.status.deactivated")

    within("tr", text: "鈴木 一郎") { click_button I18n.t("users.activate") }

    assert_text I18n.t("users.activated")
  end

  test "自分自身を無効にしようとすると理由が示される" do
    visit users_path

    within("tr", text: users(:taro).name) { click_button I18n.t("users.deactivate") }

    assert_text I18n.t("users.cannot_deactivate_self")
  end
end
