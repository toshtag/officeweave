require "application_system_test_case"

class NotificationsTest < ApplicationSystemTestCase
  test "JavaScript なしで通知から対象の画面へ移動でき、未読が消える" do
    Notification.deliver(user: users(:hanako), subject: announcements(:company_wide),
                         event: "announcement_published")

    sign_in_as users(:hanako)

    assert_selector ".badge--unread", text: "1"

    click_link I18n.t("notifications.index.heading", locale: :en)
    click_link(
      I18n.t("notifications.events.announcement_published",
             title: announcements(:company_wide).title, locale: :en)
    )

    assert_text announcements(:company_wide).title

    visit notifications_path
    assert_no_selector ".badge--unread"
  end
end
