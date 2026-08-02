require "test_helper"

# 繰り返し予定を、画面の側から確かめる。
class RecurringEventsTest < ActionDispatch::IntegrationTest
  test "繰り返しを指定して作れる" do
    sign_in_as users(:taro)
    starts_at = 1.day.from_now.change(hour: 9, min: 0, sec: 0)

    assert_difference -> { Event.count }, 3 do
      post events_url, params: {
        event: { title: "定例会", visibility: "organization",
                 starts_at: starts_at.iso8601, ends_at: (starts_at + 1.hour).iso8601,
                 recurrence_frequency: "daily", repeat_until: (starts_at.to_date + 2).to_s }
      }
    end

    assert_response :redirect
  end

  test "繰り返しを指定しなければ 1 件だけ作る" do
    sign_in_as users(:taro)
    starts_at = 1.day.from_now.change(hour: 9, min: 0, sec: 0)

    assert_difference -> { Event.count }, 1 do
      post events_url, params: {
        event: { title: "単発の予定", visibility: "organization",
                 starts_at: starts_at.iso8601, ends_at: (starts_at + 1.hour).iso8601,
                 recurrence_frequency: "", repeat_until: "" }
      }
    end
  end

  test "誤った繰り返しの指定は理由を示す" do
    sign_in_as users(:taro)
    starts_at = 1.day.from_now.change(hour: 9, min: 0, sec: 0)

    assert_no_difference -> { Event.count } do
      post events_url, params: {
        event: { title: "遠すぎる繰り返し", visibility: "organization",
                 starts_at: starts_at.iso8601, ends_at: (starts_at + 1.hour).iso8601,
                 recurrence_frequency: "daily", repeat_until: (starts_at.to_date + 365).to_s }
      }
    end

    assert_response :unprocessable_content
    assert_select ".error-summary"
  end

  test "この回以降をまとめて消せる" do
    sign_in_as users(:taro)
    series = create_series

    assert_difference -> { Event.count }, -2 do
      delete event_url(series.second, scope: "following")
    end

    assert_redirected_to events_path
    assert Event.exists?(series.first.id)
  end

  test "指定が無ければ 1 回だけ消す" do
    sign_in_as users(:taro)
    series = create_series

    assert_difference -> { Event.count }, -1 do
      delete event_url(series.second)
    end
  end

  test "繰り返しの一部にはまとめて消す操作が出る" do
    sign_in_as users(:taro)
    series = create_series

    get event_url(series.first)

    assert_select "form[action=?]", event_path(series.first, scope: "following")
  end

  test "繰り返しでない予定にはまとめて消す操作を出さない" do
    sign_in_as users(:taro)

    get event_url(events(:taro_private))

    assert_select "form[action=?]", event_path(events(:taro_private), scope: "following"), count: 0
  end

  private
    # 3 回の繰り返しを作る。
    def create_series
      starts_at = 1.day.from_now.change(hour: 9, min: 0, sec: 0)
      event = organizations(:main).events.new(owner: users(:taro), title: "定例", visibility: "private",
                                             starts_at: starts_at, ends_at: starts_at + 1.hour)
      Event::Recurrence.new(event, frequency: "daily", repeat_until: starts_at.to_date + 2).save

      Event.where(series_id: event.reload.series_id).chronological.to_a
    end
end
