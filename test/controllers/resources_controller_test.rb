require "test_helper"

class ResourcesControllerTest < ActionDispatch::IntegrationTest
  test "自組織の設備・備品だけが並ぶ" do
    sign_in_as users(:hanako)

    get resources_url

    assert_response :success
    assert_select "td", text: resources(:meeting_room_a).code
    assert_select "a", text: resources(:other_org_room).name, count: 0
  end

  test "一般利用者は登録できない" do
    sign_in_as users(:hanako)

    assert_no_difference -> { Resource.count } do
      post resources_url, params: { resource: { name: "会議室 C", code: "room-c" } }
    end

    assert_response :forbidden
  end

  test "管理者は登録できる" do
    sign_in_as users(:taro)

    assert_difference -> { Resource.count }, 1 do
      post resources_url, params: { resource: { name: "会議室 C", code: "room-c" } }
    end
  end

  test "管理者は受付を停止できる" do
    sign_in_as users(:taro)

    patch resource_url(resources(:meeting_room_a)), params: { resource: { reservable: "0" } }

    assert_not_predicate resources(:meeting_room_a).reload, :reservable?
  end

  test "削除の経路は用意していない" do
    sign_in_as users(:taro)

    delete resource_url(resources(:meeting_room_a))

    assert_response :not_found
    assert_predicate Resource, :exists?
  end

  test "別組織の設備・備品は参照できない" do
    sign_in_as users(:taro)

    get resource_url(resources(:other_org_room))

    assert_response :not_found
  end
end
