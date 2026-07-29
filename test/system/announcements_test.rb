require "application_system_test_case"

class AnnouncementsTest < ApplicationSystemTestCase
  test "JavaScript なしでお知らせを作成し、部門を指定して公開できる" do
    sign_in_as users(:taro)

    visit announcements_path
    click_link I18n.t("announcements.index.new")

    fill_in Announcement.human_attribute_name(:title), with: "設備点検のお知らせ"
    fill_in Announcement.human_attribute_name(:body), with: "来週、設備点検を行います。"
    choose I18n.t("announcements.visibilities.departments")
    check departments(:development).display_path
    fill_in Announcement.human_attribute_name(:published_at), with: Time.current.strftime("%Y-%m-%dT%H:%M")
    click_button I18n.t("helpers.submit.create")

    assert_text I18n.t("announcements.created")
    assert_text "設備点検のお知らせ"
    assert_text departments(:development).display_path
  end

  test "公開先に含まれない利用者には表示されない" do
    sign_in_as users(:hanako)

    visit announcements_path

    assert_text announcements(:company_wide).title
    assert_no_text announcements(:sales_only).title
  end

  test "公開先を指定せずに部門限定にすると理由が示される" do
    sign_in_as users(:taro)

    visit new_announcement_path
    fill_in Announcement.human_attribute_name(:title), with: "連絡"
    fill_in Announcement.human_attribute_name(:body), with: "本文"
    choose I18n.t("announcements.visibilities.departments")
    click_button I18n.t("helpers.submit.create")

    assert_selector ".error-summary"
  end
end
