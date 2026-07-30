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

  test "最後の管理者を一般利用者へ変えようとすると理由が示される" do
    visit edit_user_path(users(:taro))

    select I18n.t("roles.member"), from: User.human_attribute_name(:role)
    click_button I18n.t("helpers.submit.update")

    assert_text I18n.t("activerecord.errors.models.user.attributes.base.last_active_administrator")

    visit users_path

    assert_predicate users(:taro).reload, :administrator?
  end

  test "管理者が 2 人いれば一般利用者へ変えられる" do
    users(:hanako).update!(role: "administrator")

    visit edit_user_path(users(:taro))

    select I18n.t("roles.member"), from: User.human_attribute_name(:role)
    click_button I18n.t("helpers.submit.update")

    assert_text I18n.t("users.updated")
    assert_predicate users(:taro).reload, :member?
    assert_predicate users(:hanako).reload, :administrator?
  end
end
