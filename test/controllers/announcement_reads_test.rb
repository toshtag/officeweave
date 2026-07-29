require "test_helper"

class AnnouncementReadsTest < ActionDispatch::IntegrationTest
  test "お知らせを開くと既読になる" do
    sign_in_as users(:hanako)

    assert_difference -> { AnnouncementRead.count }, 1 do
      get announcement_url(announcements(:company_wide))
    end
  end

  test "同じお知らせを何度開いても記録は 1 件のままになる" do
    sign_in_as users(:hanako)

    get announcement_url(announcements(:company_wide))

    assert_no_difference -> { AnnouncementRead.count } do
      get announcement_url(announcements(:company_wide))
    end
  end

  test "下書きを開いても既読の記録は作らない" do
    sign_in_as users(:taro)

    assert_no_difference -> { AnnouncementRead.count } do
      get announcement_url(announcements(:draft))
    end
  end

  test "一覧では未読が判別できる" do
    sign_in_as users(:hanako)

    get announcements_url
    assert_select ".badge--unread", minimum: 1

    announcements(:company_wide).mark_as_read_by(users(:hanako))

    get announcements_url
    assert_select ".badge--unread", count: 0
  end

  test "ホームに未読の件数が出る" do
    sign_in_as users(:hanako)

    get root_url

    assert_select ".badge--unread", text: I18n.t("announcements.unread_count", count: 1, locale: :en)
  end
end
