require "test_helper"

class AnnouncementsControllerTest < ActionDispatch::IntegrationTest
  test "一般利用者には公開範囲に入るものだけが並ぶ" do
    sign_in_as users(:hanako)

    get announcements_url

    assert_response :success
    assert_select "h2 a", text: announcements(:company_wide).title
    assert_select "h2 a", text: announcements(:sales_only).title, count: 0
    assert_select "h3 a", text: announcements(:draft).title, count: 0
  end

  test "所属している部門宛のお知らせは並ぶ" do
    sign_in_as users(:taro)

    get announcements_url

    assert_select "h2 a", text: announcements(:sales_only).title
  end

  test "管理者には下書きも並ぶ" do
    sign_in_as users(:taro)

    get announcements_url

    assert_select "h3 a", text: announcements(:draft).title
  end

  test "公開範囲外のお知らせは参照できない" do
    sign_in_as users(:hanako)

    get announcement_url(announcements(:sales_only))

    assert_response :not_found
  end

  test "別組織のお知らせは管理者でも参照できない" do
    sign_in_as users(:taro)

    get announcement_url(announcements(:other_org))

    assert_response :not_found
  end

  test "管理者はお知らせを作成できる" do
    sign_in_as users(:taro)

    assert_difference -> { Announcement.count }, 1 do
      post announcements_url, params: {
        announcement: { title: "連絡", body: "本文", visibility: "organization",
                        published_at: Time.current.to_fs(:db) }
      }
    end

    assert_equal users(:taro), Announcement.last.author
  end

  test "組織全体へ公開する場合、指定した部門は取り除かれる" do
    sign_in_as users(:taro)

    post announcements_url, params: {
      announcement: { title: "連絡", body: "本文", visibility: "organization",
                      department_ids: [ departments(:sales).id ], published_at: Time.current.to_fs(:db) }
    }

    assert_empty Announcement.last.departments
  end

  test "一般利用者はお知らせを作成できない" do
    sign_in_as users(:hanako)

    assert_no_difference -> { Announcement.count } do
      post announcements_url, params: { announcement: { title: "連絡", body: "本文" } }
    end

    assert_response :forbidden
  end

  test "管理者はお知らせを削除できる" do
    sign_in_as users(:taro)

    assert_difference -> { Announcement.count }, -1 do
      delete announcement_url(announcements(:company_wide))
    end
  end
end
