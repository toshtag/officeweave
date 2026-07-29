require "test_helper"

class AnnouncementTest < ActiveSupport::TestCase
  test "組織全体のお知らせは所属に関わらず見える" do
    assert_includes Announcement.visible_to(users(:hanako)), announcements(:company_wide)
  end

  test "部門を指定したお知らせは、その部門の所属者だけに見える" do
    assert_includes Announcement.visible_to(users(:taro)), announcements(:sales_only)
    assert_not_includes Announcement.visible_to(users(:hanako)), announcements(:sales_only)
  end

  test "下書きは誰にも見えない" do
    assert_not_includes Announcement.visible_to(users(:taro)), announcements(:draft)
  end

  test "公開日時が未来のものは、その時刻まで見えない" do
    assert_not_includes Announcement.visible_to(users(:taro)), announcements(:scheduled)

    travel_to 4.days.from_now do
      assert_includes Announcement.visible_to(users(:taro)), announcements(:scheduled)
    end
  end

  test "別組織のお知らせは見えない" do
    assert_not_includes Announcement.visible_to(users(:taro)), announcements(:other_org)
  end

  test "部門を指定した場合、公開先が空では保存できない" do
    announcement = organizations(:main).announcements.new(
      author: users(:taro), title: "連絡", body: "本文", visibility: "departments"
    )

    assert_not announcement.valid?
  end

  test "別組織の部門は公開先に指定できない" do
    announcement = organizations(:main).announcements.new(
      author: users(:taro), title: "連絡", body: "本文",
      visibility: "departments", departments: [ departments(:other_general) ]
    )

    assert_not announcement.valid?
  end

  test "同じ部門を二重に公開先へ指定できない" do
    announcement = announcements(:sales_only)
    duplicate = announcement.announcement_departments.new(department: departments(:sales))

    assert_not duplicate.valid?
  end
end
