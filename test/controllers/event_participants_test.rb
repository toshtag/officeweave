require "test_helper"

# 予定の参加者を、画面の側から確かめる。
class EventParticipantsTest < ActionDispatch::IntegrationTest
  test "作成のときに参加者を指名できる" do
    sign_in_as users(:taro)

    post events_url, params: {
      event: { title: "参加者つきの予定", visibility: "private",
               starts_at: 1.day.from_now.change(hour: 9).iso8601,
               ends_at: 1.day.from_now.change(hour: 10).iso8601,
               participant_ids: [ users(:hanako).id ] }
    }

    event = Event.order(:created_at).last

    assert_redirected_to event_path(event)
    assert_equal [ users(:hanako) ], event.participants
  end

  test "変更のときに参加者を入れ替えられる" do
    event = events(:taro_private)
    event.participants = [ users(:hanako) ]
    sign_in_as users(:taro)

    patch event_url(event), params: {
      event: { title: event.title, visibility: event.visibility,
               starts_at: event.starts_at.iso8601, ends_at: event.ends_at.iso8601,
               participant_ids: [ users(:approver).id ] }
    }

    assert_redirected_to event_path(event)
    assert_equal [ users(:approver) ], event.reload.participants
  end

  test "参加者を空にできる" do
    event = events(:taro_private)
    event.participants = [ users(:hanako) ]
    sign_in_as users(:taro)

    patch event_url(event), params: {
      event: { title: event.title, visibility: event.visibility,
               starts_at: event.starts_at.iso8601, ends_at: event.ends_at.iso8601 }
    }

    assert_empty event.reload.participants
  end

  test "他の組織の利用者は指名できない" do
    sign_in_as users(:taro)

    post events_url, params: {
      event: { title: "別組織を指名", visibility: "private",
               starts_at: 1.day.from_now.change(hour: 9).iso8601,
               ends_at: 1.day.from_now.change(hour: 10).iso8601,
               participant_ids: [ users(:outsider).id ] }
    }

    assert_empty Event.order(:created_at).last.participants
  end

  test "参加者は予定を開ける" do
    event = events(:taro_private)
    event.participants = [ users(:hanako) ]
    sign_in_as users(:hanako)

    get event_url(event)

    assert_response :success
  end

  test "参加者でなければ非公開の予定は開けない" do
    sign_in_as users(:hanako)

    get event_url(events(:taro_private))

    assert_response :not_found
  end

  test "予定の画面に参加者が出る" do
    event = events(:taro_private)
    event.participants = [ users(:hanako) ]
    sign_in_as users(:taro)

    get event_url(event)

    assert_select "[data-event-participants]", text: /#{users(:hanako).name}/
  end

  test "選択肢に自分自身を並べない" do
    sign_in_as users(:taro)

    get new_event_url

    assert_select "input[name='event[participant_ids][]'][value=?]", users(:taro).id.to_s, count: 0
    assert_select "input[name='event[participant_ids][]'][value=?]", users(:hanako).id.to_s
  end
end
