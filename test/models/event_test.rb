require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "組織全体の予定は誰にでも見える" do
    assert_includes Event.visible_to(users(:hanako)), events(:company_meeting)
  end

  test "個人の予定は持ち主にだけ見える" do
    assert_includes Event.visible_to(users(:taro)), events(:taro_private)
    assert_not_includes Event.visible_to(users(:hanako)), events(:taro_private)
  end

  test "部門を指定した予定は、その部門の所属者だけに見える" do
    assert_includes Event.visible_to(users(:taro)), events(:sales_review)
    assert_not_includes Event.visible_to(users(:hanako)), events(:sales_review)
  end

  test "別組織の予定は見えない" do
    assert_not_includes Event.visible_to(users(:taro)), events(:other_org_event)
  end

  test "終了が開始より前だと保存できない" do
    event = organizations(:main).events.new(
      owner: users(:taro), title: "打ち合わせ",
      starts_at: 1.day.from_now, ends_at: 1.day.from_now - 1.hour
    )

    assert_not event.valid?
  end

  test "終了と開始が同時刻だと保存できない" do
    time = 1.day.from_now
    event = organizations(:main).events.new(owner: users(:taro), title: "打ち合わせ", starts_at: time, ends_at: time)

    assert_not event.valid?
  end

  test "指定した日時以降の予定だけを取り出せる" do
    upcoming = Event.starting_from(Time.current)

    assert_includes upcoming, events(:company_meeting)
    assert_not_includes upcoming, events(:past_event)
  end

  test "持ち主と管理者だけが変更できる" do
    assert events(:taro_private).editable_by?(users(:taro))
    assert_not events(:company_meeting).editable_by?(users(:hanako))
  end

  test "部門を指定した場合、公開先が空では保存できない" do
    event = organizations(:main).events.new(
      owner: users(:taro), title: "打ち合わせ", visibility: "departments",
      starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour
    )

    assert_not event.valid?
  end
end
