require "test_helper"

class ResourceTest < ActiveSupport::TestCase
  test "名称と識別子があれば登録できる" do
    resource = organizations(:main).resources.new(name: "会議室 C", code: "room-c")

    assert resource.valid?
  end

  test "識別子は組織の中で重複できない" do
    resource = organizations(:main).resources.new(name: "別の会議室 A", code: "room-a")

    assert_not resource.valid?
  end

  test "識別子は組織が違えば重複できる" do
    assert_predicate resources(:other_org_room), :valid?
  end

  test "定員は 1 以上でなければならない" do
    resource = organizations(:main).resources.new(name: "会議室 C", code: "room-c", capacity: 0)

    assert_not resource.valid?
  end

  test "定員は指定しなくてもよい" do
    resource = organizations(:main).resources.new(name: "会議室 C", code: "room-c", capacity: nil)

    assert resource.valid?
  end

  test "予約を受け付けるものだけを取り出せる" do
    reservable = organizations(:main).resources.reservable

    assert_includes reservable, resources(:meeting_room_a)
    assert_not_includes reservable, resources(:retired_projector)
  end
end
