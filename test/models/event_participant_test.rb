require "test_helper"

# 予定の参加者。
#
# 予定に関わる利用者を指名する。参加者は、公開範囲に関わらずその予定を
# 見られる。見られないと、指名された当人が内容を確かめられない。
class EventParticipantTest < ActiveSupport::TestCase
  setup do
    @event = events(:taro_private)
  end

  test "参加者を指名できる" do
    @event.participants = [ users(:hanako) ]

    assert_equal [ users(:hanako) ], @event.reload.participants
  end

  test "参加者は公開範囲に関わらず見られる" do
    # 非公開の予定でも、指名された当人は見られる。
    refute_includes Event.visible_to(users(:hanako)), @event

    @event.participants = [ users(:hanako) ]

    assert_includes Event.visible_to(users(:hanako)), @event
  end

  test "参加者から外すと見られなくなる" do
    @event.participants = [ users(:hanako) ]
    @event.participants = []

    refute_includes Event.visible_to(users(:hanako)), @event
  end

  test "同じ利用者を二重に指名しない" do
    @event.event_participants.create!(user: users(:hanako))
    duplicate = @event.event_participants.new(user: users(:hanako))

    assert_not duplicate.valid?
  end

  test "所有者は参加者にしない" do
    # 所有者は指名しなくても見られる。並べると、外せない参加者ができる。
    participant = @event.event_participants.new(user: @event.owner)

    assert_not participant.valid?
    assert_includes participant.errors.attribute_names, :user
  end

  test "他の組織の利用者は参加者にできない" do
    participant = @event.event_participants.new(user: users(:outsider))

    assert_not participant.valid?
  end

  test "無効化された利用者は参加者にできない" do
    users(:hanako).deactivate!

    assert_not @event.event_participants.new(user: users(:hanako)).valid?
  end

  test "予定を消すと参加者の記録も消える" do
    @event.participants = [ users(:hanako) ]

    assert_difference -> { EventParticipant.count }, -1 do
      @event.destroy
    end
  end

  test "参加者を指名すると知らせる" do
    assert_difference -> { Notification.where(user: users(:hanako), event: "event_invited").count }, 1 do
      @event.invite(users: [ users(:hanako) ], actor: @event.owner)
    end
  end

  test "既に参加者である利用者へは重ねて知らせない" do
    @event.invite(users: [ users(:hanako) ], actor: @event.owner)

    assert_no_difference -> { Notification.where(event: "event_invited").count } do
      @event.invite(users: [ users(:hanako) ], actor: @event.owner)
    end
  end

  test "外した参加者へは知らせない" do
    @event.invite(users: [ users(:hanako) ], actor: @event.owner)

    assert_no_difference -> { Notification.where(event: "event_invited").count } do
      @event.invite(users: [], actor: @event.owner)
    end

    assert_empty @event.reload.participants
  end
end
