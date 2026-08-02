require "test_helper"

# 予約の変更。
#
# 取り消して作り直す以外に手が無かった。作り直すと、その隙に同じ時間帯を
# 別の利用者が取れる。予約の識別子も変わり、予定との結び付きを作り直す。
class ReservationChangeTest < ActionDispatch::IntegrationTest
  setup do
    @reservation = reservations(:room_a_morning)
  end

  test "持ち主は変更できる" do
    sign_in_as @reservation.reserver

    patch reservation_url(@reservation), params: {
      reservation: { resource_id: @reservation.resource_id, purpose: "変更後の用途",
                     starts_at: starts_at, ends_at: ends_at }
    }

    assert_redirected_to reservations_path
    assert_equal "変更後の用途", @reservation.reload.purpose
  end

  test "時間帯を変更できる" do
    sign_in_as @reservation.reserver
    moved = @reservation.starts_at + 3.hours

    patch reservation_url(@reservation), params: {
      reservation: { resource_id: @reservation.resource_id, starts_at: moved.iso8601,
                     ends_at: (moved + 1.hour).iso8601 }
    }

    assert_redirected_to reservations_path
    assert_equal moved.change(usec: 0), @reservation.reload.starts_at.change(usec: 0)
  end

  test "時間帯を変えずに保存できる" do
    # 自分自身と重なっていると判定すると、用途だけの変更もできない。
    sign_in_as @reservation.reserver

    patch reservation_url(@reservation), params: {
      reservation: { resource_id: @reservation.resource_id, purpose: "用途だけ変える",
                     starts_at: @reservation.starts_at.iso8601, ends_at: @reservation.ends_at.iso8601 }
    }

    assert_redirected_to reservations_path
  end

  test "管理者は他の利用者の予約を変更できる" do
    sign_in_as users(:taro)

    patch reservation_url(reservations(:room_a_afternoon)), params: {
      reservation: { resource_id: reservations(:room_a_afternoon).resource_id, purpose: "管理者が直す",
                     starts_at: reservations(:room_a_afternoon).starts_at.iso8601,
                     ends_at: reservations(:room_a_afternoon).ends_at.iso8601 }
    }

    assert_redirected_to reservations_path
    assert_equal "管理者が直す", reservations(:room_a_afternoon).reload.purpose
  end

  test "他の利用者は変更できない" do
    sign_in_as users(:outsider_free)

    patch reservation_url(@reservation), params: {
      reservation: { resource_id: @reservation.resource_id, purpose: "横から直す",
                     starts_at: @reservation.starts_at.iso8601, ends_at: @reservation.ends_at.iso8601 }
    }

    assert_response :forbidden
    assert_not_equal "横から直す", @reservation.reload.purpose
  end

  test "重なる時間帯へは変更できない" do
    other = reservations(:room_a_afternoon)
    sign_in_as @reservation.reserver

    patch reservation_url(@reservation), params: {
      reservation: { resource_id: other.resource_id, starts_at: other.starts_at.iso8601,
                     ends_at: other.ends_at.iso8601 }
    }

    assert_response :unprocessable_content
    assert_not_equal other.starts_at, @reservation.reload.starts_at
  end

  test "参照できない予定へは結び付けられない" do
    sign_in_as @reservation.reserver

    patch reservation_url(@reservation), params: {
      reservation: { resource_id: @reservation.resource_id, event_id: events(:other_org_event).id,
                     starts_at: @reservation.starts_at.iso8601, ends_at: @reservation.ends_at.iso8601 }
    }

    assert_response :unprocessable_content
    assert_nil @reservation.reload.event_id
  end

  test "他の組織の予約は扱えない" do
    sign_in_as users(:taro)

    assert_raises(ActiveRecord::RecordNotFound) do
      get edit_reservation_url(reservations(:other_org_reservation))
    end
  end

  test "変更の画面を開ける" do
    sign_in_as @reservation.reserver

    get edit_reservation_url(@reservation)

    assert_response :success
    assert_select "form[action=?]", reservation_path(@reservation)
  end

  test "一覧から変更へ行ける" do
    sign_in_as @reservation.reserver

    get reservations_url

    assert_select "a[href=?]", edit_reservation_path(@reservation)
  end

  test "変更できない予約には変更への案内を出さない" do
    sign_in_as users(:outsider_free)

    get reservations_url

    assert_select "a[href=?]", edit_reservation_path(@reservation), count: 0
  end

  private
    def starts_at = @reservation.starts_at.iso8601
    def ends_at = @reservation.ends_at.iso8601
end
