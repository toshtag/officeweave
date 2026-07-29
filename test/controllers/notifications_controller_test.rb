require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @notification = Notification.deliver(user: users(:hanako), subject: announcements(:company_wide),
                                         event: "announcement_published")
    sign_in_as users(:hanako)
  end

  test "自分宛の通知だけが並ぶ" do
    other = Notification.deliver(user: users(:taro), subject: announcements(:company_wide),
                                 event: "announcement_published")

    get notifications_url

    assert_response :success
    assert_select "a[href=?]", notification_path(@notification)
    assert_select "a[href=?]", notification_path(other), count: 0
  end

  test "通知を開くと既読になり、対象の画面へ移動する" do
    get notification_url(@notification)

    assert_redirected_to announcement_path(announcements(:company_wide))
    assert_predicate @notification.reload, :read?
  end

  test "他人宛の通知は開けない" do
    other = Notification.deliver(user: users(:taro), subject: announcements(:company_wide),
                                 event: "announcement_published")

    get notification_url(other)

    assert_response :not_found
  end

  test "見出し領域に未読の件数が出る" do
    get root_url

    assert_select ".badge--unread", text: "1"
  end

  test "申請の通知は申請の画面へ移動する" do
    notification = Notification.deliver(user: users(:hanako), subject: requests(:hanako_expense_pending),
                                        event: "request_approved")

    get notification_url(notification)

    assert_redirected_to request_path(requests(:hanako_expense_pending))
  end
end
