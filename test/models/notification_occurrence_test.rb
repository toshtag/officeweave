require "test_helper"

# 通知を二重に作らない単位。
#
# 受け手と対象と種類だけで一意にすると、差し戻したあとの再提出や、同じ
# 利用者が担当する 2 つ目の段で、新しい未読が作られない。届いたことに
# 気付けないまま止まる。
#
# 一方で、同じ発生に対して何度呼んでも増えてはならない。ジョブのやり直しは
# 同じ呼び出しを繰り返す。
class NotificationOccurrenceTest < ActiveSupport::TestCase
  setup do
    @request = requests(:taro_leave_pending)
    @approver = users(:approver)
    Notification.where(subject: @request).delete_all
  end

  test "発生が違えば、同じ受け手へもう 1 件作る" do
    first = deliver(occurrence: "activity:1")
    second = deliver(occurrence: "activity:2")

    assert_not_nil first
    assert_not_nil second
    assert_equal 2, Notification.where(subject: @request, user: @approver).count
  end

  test "同じ発生を二度呼んでも増えない" do
    deliver(occurrence: "activity:1")

    assert_nil deliver(occurrence: "activity:1")
    assert_equal 1, Notification.where(subject: @request, user: @approver).count
  end

  test "読んだあとでも、別の発生なら新しい未読になる" do
    deliver(occurrence: "activity:1")
    Notification.where(subject: @request).update_all(read_at: Time.current)

    deliver(occurrence: "activity:2")

    assert_equal 1, Notification.where(subject: @request, user: @approver).unread.count
  end

  test "発生を指定しない出来事は、対象につき 1 件だけ作る" do
    announcement = announcements(:company_wide)

    assert_not_nil Notification.deliver(user: @approver, subject: announcement, event: "announcement_published")
    assert_nil Notification.deliver(user: @approver, subject: announcement, event: "announcement_published")
  end

  test "まとめて作る経路でも、発生が違えば作り直す" do
    first = Notification.deliver_to_all(users: [ @approver ], subject: @request,
                                        event: "request_submitted", occurrence: "activity:1")
    second = Notification.deliver_to_all(users: [ @approver ], subject: @request,
                                         event: "request_submitted", occurrence: "activity:2")

    assert_equal 1, first.size
    assert_equal 1, second.size
  end

  test "まとめて作る経路でも、同じ発生では増えない" do
    Notification.deliver_to_all(users: [ @approver ], subject: @request,
                                event: "request_submitted", occurrence: "activity:1")
    again = Notification.deliver_to_all(users: [ @approver ], subject: @request,
                                        event: "request_submitted", occurrence: "activity:1")

    assert_empty again
    assert_equal 1, Notification.where(subject: @request, user: @approver).count
  end

  test "無効にされた利用者へは作らない" do
    @approver.update!(deactivated_at: Time.current)

    assert_nil deliver(occurrence: "activity:1")
    assert_empty Notification.deliver_to_all(users: [ @approver ], subject: @request,
                                             event: "request_submitted", occurrence: "activity:1")
  end

  test "組織の境界を越える通知は作らない" do
    outsider = users(:outsider)

    assert_raises(ActiveRecord::RecordInvalid) do
      Notification.deliver(user: outsider, subject: @request, event: "request_submitted",
                           occurrence: "activity:1")
    end
  end

  test "発生の値には上限がある" do
    notification = Notification.new(user: @approver, subject: @request, event: "request_submitted",
                                    occurrence: "a" * 101)

    assert_not notification.valid?
    assert_includes notification.errors.attribute_names, :occurrence
  end

  private
    def deliver(occurrence:)
      Notification.deliver(user: @approver, subject: @request, event: "request_submitted",
                           occurrence: occurrence)
    end
end
