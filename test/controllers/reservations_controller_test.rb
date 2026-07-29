require "test_helper"

class ReservationsControllerTest < ActionDispatch::IntegrationTest
  setup { @base = 1.day.from_now.change(hour: 9) }

  test "自組織の予約だけが並ぶ" do
    sign_in_as users(:hanako)

    get reservations_url

    assert_response :success
    assert_select "td", text: resources(:meeting_room_a).name
  end

  test "予約できる" do
    sign_in_as users(:hanako)

    assert_difference -> { Reservation.count }, 1 do
      post reservations_url, params: {
        reservation: { resource_id: resources(:meeting_room_a).id,
                       starts_at: @base.change(hour: 13).strftime("%Y-%m-%d %H:%M"),
                       ends_at: @base.change(hour: 14).strftime("%Y-%m-%d %H:%M"), purpose: "面談" }
      }
    end

    assert_equal users(:hanako), Reservation.last.reserver
  end

  test "重なる時間帯は予約できず、理由が示される" do
    sign_in_as users(:hanako)

    assert_no_difference -> { Reservation.count } do
      post reservations_url, params: {
        reservation: { resource_id: resources(:meeting_room_a).id,
                       starts_at: @base.change(hour: 9, min: 30).strftime("%Y-%m-%d %H:%M"),
                       ends_at: @base.change(hour: 10, min: 30).strftime("%Y-%m-%d %H:%M") }
      }
    end

    assert_response :unprocessable_content
    assert_select ".error-summary"
  end

  test "予定と結びつけて予約できる" do
    sign_in_as users(:hanako)

    post reservations_url, params: {
      reservation: { resource_id: resources(:meeting_room_a).id, event_id: events(:company_meeting).id,
                     starts_at: @base.change(hour: 13).strftime("%Y-%m-%d %H:%M"),
                     ends_at: @base.change(hour: 14).strftime("%Y-%m-%d %H:%M") }
    }

    assert_equal events(:company_meeting), Reservation.last.event
  end

  test "予約者でない一般利用者は取り消せない" do
    sign_in_as users(:hanako)

    assert_no_difference -> { Reservation.count } do
      delete reservation_url(reservations(:room_a_morning))
    end

    assert_response :forbidden
  end

  test "予約者は取り消せる" do
    sign_in_as users(:taro)

    assert_difference -> { Reservation.count }, -1 do
      delete reservation_url(reservations(:room_a_morning))
    end
  end

  test "表示開始日が日付として読めない場合は一覧へ戻す" do
    sign_in_as users(:taro)

    get reservations_url(from: "not-a-date")

    assert_redirected_to reservations_path
  end
end
