require "test_helper"

class NotificationDeliveryTest < ActiveSupport::TestCase
  test "申請の提出で承認できる利用者へ通知が届く" do
    request = requests(:hanako_leave_draft)

    assert_difference -> { users(:taro).notifications.count }, 1 do
      request.submit(actor: users(:hanako))
    end

    assert_equal "request_submitted", users(:taro).notifications.recent_first.first.event
  end

  test "承認で申請者へ通知が届く" do
    assert_difference -> { users(:hanako).notifications.count }, 1 do
      requests(:hanako_expense_pending).approve(actor: users(:taro))
    end
  end

  test "差し戻しで申請者へ通知が届く" do
    assert_difference -> { users(:hanako).notifications.count }, 1 do
      requests(:hanako_expense_pending).return_to_applicant(actor: users(:taro))
    end
  end

  test "許可されない遷移では通知しない" do
    assert_no_difference -> { Notification.count } do
      requests(:hanako_leave_draft).approve(actor: users(:taro))
    end
  end

  test "組織全体のお知らせは全員が受け取る" do
    recipients = announcements(:company_wide).recipients

    assert_includes recipients, users(:hanako)
    assert_includes recipients, users(:taro)
    assert_not_includes recipients, users(:outsider)
  end

  test "部門を指定したお知らせは、その部門の所属者だけが受け取る" do
    recipients = announcements(:sales_only).recipients

    assert_includes recipients, users(:taro)
    assert_not_includes recipients, users(:hanako)
  end

  test "無効にされた利用者は受け取らない" do
    users(:hanako).deactivate!

    assert_not_includes announcements(:company_wide).recipients, users(:hanako)
  end
end
