require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  test "通知を作れる" do
    assert_difference -> { Notification.count }, 1 do
      Notification.deliver(user: users(:hanako), subject: announcements(:company_wide),
                           event: "announcement_published")
    end
  end

  test "同じ出来事について二重に通知しない" do
    Notification.deliver(user: users(:hanako), subject: announcements(:company_wide),
                         event: "announcement_published")

    assert_no_difference -> { Notification.count } do
      Notification.deliver(user: users(:hanako), subject: announcements(:company_wide),
                           event: "announcement_published")
    end
  end

  test "無効にされた利用者へは通知しない" do
    users(:hanako).deactivate!

    assert_no_difference -> { Notification.count } do
      Notification.deliver(user: users(:hanako), subject: announcements(:company_wide),
                           event: "announcement_published")
    end
  end

  test "既読にできる" do
    notification = Notification.deliver(user: users(:hanako), subject: announcements(:company_wide),
                                        event: "announcement_published")

    notification.mark_as_read

    assert_predicate notification, :read?
  end

  test "対象を削除すると通知も取り除かれる" do
    Notification.deliver(user: users(:hanako), subject: announcements(:company_wide),
                         event: "announcement_published")

    assert_difference -> { Notification.count }, -1 do
      announcements(:company_wide).destroy
    end
  end
end
