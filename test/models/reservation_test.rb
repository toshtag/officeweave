require "test_helper"

class ReservationTest < ActiveSupport::TestCase
  setup do
    @base = 1.day.from_now.change(hour: 9)
  end

  test "空いている時間帯なら予約できる" do
    reservation = build(starts_at: @base.change(hour: 13), ends_at: @base.change(hour: 14))

    assert reservation.valid?
  end

  test "既存の予約と重なる時間帯は予約できない" do
    reservation = build(starts_at: @base.change(hour: 9, min: 30), ends_at: @base.change(hour: 10, min: 30))

    assert_not reservation.valid?
    assert_predicate reservation.errors[:base], :present?
  end

  test "既存の予約を包む時間帯は予約できない" do
    reservation = build(starts_at: @base.change(hour: 8), ends_at: @base.change(hour: 11))

    assert_not reservation.valid?
  end

  test "終了時刻と開始時刻が同じなら重ならない" do
    reservation = build(starts_at: @base.change(hour: 10), ends_at: @base.change(hour: 11))

    assert reservation.valid?
  end

  test "別の設備・備品なら同じ時間帯を予約できる" do
    reservation = build(resource: resources(:meeting_room_b),
                        starts_at: @base.change(hour: 9), ends_at: @base.change(hour: 10))

    assert reservation.valid?
  end

  test "受付を停止している設備・備品は予約できない" do
    reservation = build(resource: resources(:retired_projector),
                        starts_at: @base.change(hour: 13), ends_at: @base.change(hour: 14))

    assert_not reservation.valid?
  end

  test "別組織の設備・備品は予約できない" do
    reservation = build(resource: resources(:other_org_room),
                        starts_at: @base.change(hour: 13), ends_at: @base.change(hour: 14))

    assert_not reservation.valid?
  end

  test "別組織の予定は予約に結び付けられない" do
    reservation = build(event: events(:other_org_event),
                        starts_at: @base.change(hour: 13), ends_at: @base.change(hour: 14))

    assert_not reservation.valid?
    assert_includes reservation.errors.details[:event], { error: :not_visible }
  end

  test "予約者が参照できない予定は結び付けられない" do
    reservation = build(event: events(:taro_private),
                        starts_at: @base.change(hour: 13), ends_at: @base.change(hour: 14))

    assert_not reservation.valid?
    assert_includes reservation.errors.details[:event], { error: :not_visible }
  end

  test "存在しない予定の識別子は結び付けられない" do
    reservation = build(starts_at: @base.change(hour: 13), ends_at: @base.change(hour: 14))
    reservation.event_id = Event.maximum(:id).to_i + 1

    assert_not reservation.valid?
    assert_includes reservation.errors.details[:event], { error: :not_visible }
  end

  # 誤りの内容が分かれると、識別子を送るだけで予定の存在と所属組織を判別できる。
  test "参照できない予定は、理由によらず同じ誤りになる" do
    messages = [
      events(:other_org_event).id,
      events(:taro_private).id,
      Event.maximum(:id).to_i + 1
    ].map do |event_id|
      reservation = build(starts_at: @base.change(hour: 13), ends_at: @base.change(hour: 14))
      reservation.event_id = event_id
      reservation.valid?

      reservation.errors.full_messages_for(:event)
    end

    assert_equal 1, messages.uniq.length, messages.inspect
    assert_predicate messages.first, :present?
  end

  # 公開範囲が部門指定の予定も、その部門に所属していれば結び付けられる。
  test "予約者が参照できる予定なら結び付けられる" do
    reservation = build(event: events(:sales_review), reserver: users(:taro),
                        starts_at: @base.change(hour: 13), ends_at: @base.change(hour: 14))

    assert reservation.valid?
  end

  # 持ち主は公開範囲に関わらず自分の予定を参照できる。
  test "予約者自身の非公開の予定なら結び付けられる" do
    reservation = build(event: events(:taro_private), reserver: users(:taro),
                        starts_at: @base.change(hour: 13), ends_at: @base.change(hour: 14))

    assert reservation.valid?
  end

  test "別組織の利用者は予約者に指定できない" do
    reservation = build(reserver: users(:outsider),
                        starts_at: @base.change(hour: 13), ends_at: @base.change(hour: 14))

    assert_not reservation.valid?
    assert_includes reservation.errors.details[:reserver], { error: :different_organization }
  end

  test "同じ組織の予定と予約者なら予約できる" do
    reservation = build(event: events(:company_meeting), reserver: users(:taro),
                        starts_at: @base.change(hour: 13), ends_at: @base.change(hour: 14))

    assert reservation.valid?
  end

  test "予定を結び付けない予約は従来どおり作れる" do
    reservation = build(event: nil,
                        starts_at: @base.change(hour: 13), ends_at: @base.change(hour: 14))

    assert reservation.valid?
  end

  test "終了が開始より後でなければ予約できない" do
    reservation = build(starts_at: @base.change(hour: 14), ends_at: @base.change(hour: 13))

    assert_not reservation.valid?
  end

  test "模型側の確認を飛ばしても、データベースが重なりを拒否する" do
    reservation = build(starts_at: @base.change(hour: 9, min: 30), ends_at: @base.change(hour: 10, min: 30))

    assert_raises(ActiveRecord::StatementInvalid) { reservation.save(validate: false) }
  end

  test "重なりをデータベースが拒否した場合も理由を返す" do
    reservation = build(starts_at: @base.change(hour: 9, min: 30), ends_at: @base.change(hour: 10, min: 30))
    reservation.define_singleton_method(:must_not_overlap_existing_reservation) { nil }

    assert_not reservation.save_with_overlap_check
    assert_predicate reservation.errors[:base], :present?
  end

  test "予約者と管理者だけが取り消せる" do
    assert reservations(:room_a_morning).cancelable_by?(users(:taro))
    assert_not reservations(:room_a_morning).cancelable_by?(users(:hanako))
  end

  private
    def build(**attributes)
      organizations(:main).reservations.new(
        { resource: resources(:meeting_room_a), reserver: users(:hanako) }.merge(attributes)
      )
    end
end
