require "test_helper"

class AnnouncementReadTest < ActiveSupport::TestCase
  test "読んだ記録を残せる" do
    announcement = announcements(:company_wide)

    assert_difference -> { AnnouncementRead.count }, 1 do
      announcement.mark_as_read_by(users(:hanako))
    end

    assert announcement.read_by?(users(:hanako))
  end

  test "同じ利用者の記録は二重に作らない" do
    announcement = announcements(:company_wide)
    announcement.mark_as_read_by(users(:hanako))

    assert_no_difference -> { AnnouncementRead.count } do
      announcement.mark_as_read_by(users(:hanako))
    end
  end

  test "未読の絞り込みは、読んだものを除く" do
    assert_includes Announcement.unread_for(users(:hanako)), announcements(:company_wide)

    announcements(:company_wide).mark_as_read_by(users(:hanako))

    assert_not_includes Announcement.unread_for(users(:hanako)), announcements(:company_wide)
  end

  test "既読は利用者ごとに独立している" do
    announcements(:company_wide).mark_as_read_by(users(:hanako))

    assert_not announcements(:company_wide).read_by?(users(:taro))
  end
end
