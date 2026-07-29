require "application_system_test_case"

class AnnouncementReadsSystemTest < ApplicationSystemTestCase
  test "お知らせを読むと未読の表示が消える" do
    sign_in_as users(:hanako)

    visit announcements_path
    assert_selector ".badge--unread"

    click_link announcements(:company_wide).title
    visit announcements_path

    assert_no_selector ".badge--unread"
  end

  test "他の利用者が読んでも自分の未読は残る" do
    announcements(:company_wide).mark_as_read_by(users(:taro))

    sign_in_as users(:hanako)
    visit announcements_path

    assert_selector ".badge--unread"
  end
end
