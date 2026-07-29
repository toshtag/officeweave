require "test_helper"

class EventsControllerTest < ActionDispatch::IntegrationTest
  test "見える予定だけが一覧に並ぶ" do
    sign_in_as users(:hanako)

    get events_url

    assert_response :success
    assert_select "a", text: events(:company_meeting).title
    assert_select "a", text: events(:taro_private).title, count: 0
    assert_select "a", text: events(:sales_review).title, count: 0
  end

  test "過ぎた予定は既定では並ばない" do
    sign_in_as users(:taro)

    get events_url

    assert_select "a", text: events(:past_event).title, count: 0
  end

  test "表示開始日を指定すると過去の予定も並ぶ" do
    sign_in_as users(:taro)

    get events_url(from: 10.days.ago.to_date.iso8601)

    assert_select "a", text: events(:past_event).title
  end

  test "表示開始日が日付として読めない場合は一覧へ戻す" do
    sign_in_as users(:taro)

    get events_url(from: "not-a-date")

    assert_redirected_to events_path
  end

  test "見えない予定は参照できない" do
    sign_in_as users(:hanako)

    get event_url(events(:taro_private))

    assert_response :not_found
  end

  test "予定を作成できる" do
    sign_in_as users(:hanako)

    assert_difference -> { Event.count }, 1 do
      post events_url, params: {
        event: { title: "打ち合わせ", starts_at: 1.day.from_now.to_fs(:db),
                 ends_at: (1.day.from_now + 1.hour).to_fs(:db), visibility: "private" }
      }
    end

    assert_equal users(:hanako), Event.last.owner
  end

  test "持ち主でない一般利用者は変更できない" do
    sign_in_as users(:hanako)

    get edit_event_url(events(:company_meeting))

    assert_response :forbidden
  end

  test "管理者は他人の予定も変更できる" do
    hanako_event = organizations(:main).events.create!(
      owner: users(:hanako), title: "花子の予定", visibility: "organization",
      starts_at: 1.day.from_now, ends_at: 1.day.from_now + 1.hour
    )

    sign_in_as users(:taro)

    patch event_url(hanako_event), params: { event: { title: "変更後" } }

    assert_equal "変更後", hanako_event.reload.title
  end

  test "持ち主は自分の予定を削除できる" do
    sign_in_as users(:taro)

    assert_difference -> { Event.count }, -1 do
      delete event_url(events(:taro_private))
    end
  end
end
