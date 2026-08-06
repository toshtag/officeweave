require "test_helper"

# 外部の宛先へ送る本文の形。
#
# 受け取る側は、この形に合わせて処理を書く。形を変えると相手の処理が黙って
# 壊れ、壊れたことは相手の側でしか分からない。ここで形そのものを固定する。
#
# 鍵を足すだけなら版は上げない。読み飛ばせば、これまでの処理はそのまま動く。
# 鍵を消す・名前を変える・意味を変えるときは、このテストが落ちる。
class WebhookPayloadContractTest < ActiveSupport::TestCase
  ATTRIBUTES = { subject_type: "Request", subject_id: 12, title: "休暇の申請" }.freeze

  test "送る出来事の一覧が、通知の出来事と一致する" do
    assert_equal Notification::EVENTS.sort, WebhookPayload::EVENT_KEYS.keys.sort
    assert_equal Notification::EVENTS.sort, WebhookEndpoint::EVENTS.sort
  end

  test "すべての出来事が共通の鍵を持つ" do
    Notification::EVENTS.each do |event|
      assert_equal WebhookPayload::COMMON_KEYS, WebhookPayload.keys_for(event).first(5), event
    end
  end

  test "出来事ごとの鍵を固定する" do
    expected = {
      "announcement_published" => %i[schema version event occurrence occurred_at subject_type subject_id title],
      "event_invited" => %i[schema version event occurrence occurred_at subject_type subject_id title],
      "request_submitted" => %i[schema version event occurrence occurred_at subject_type subject_id title],
      "request_approved" => %i[schema version event occurrence occurred_at subject_type subject_id title],
      "request_returned" => %i[schema version event occurrence occurred_at subject_type subject_id title]
    }

    expected.each { |event, keys| assert_equal keys, WebhookPayload.keys_for(event), event }
  end

  test "組み立てた本文が、定めた鍵だけを持つ" do
    Notification::EVENTS.each do |event|
      payload = build(event: event)

      assert_equal WebhookPayload.keys_for(event).sort, payload.keys.sort, event
    end
  end

  test "本文に形の名前と版が入る" do
    payload = build

    assert_equal "officeweave.webhook", payload[:schema]
    assert_equal 1, payload[:version]
  end

  test "発生の単位が本文に入る" do
    # 同じ本文が二度届くことがある。受け取る側は、この値で捨てられる。
    payload = build(occurrence: "activity:42")

    assert_equal "activity:42", payload[:occurrence]
  end

  test "時刻は規格の形で入れる" do
    at = Time.utc(2026, 8, 6, 12, 34, 56)

    assert_equal at.iso8601, build(occurred_at: at)[:occurred_at]
  end

  test "定めていない鍵は落とす" do
    # 呼び出す側が余分な値を渡しても、本文へは出ない。
    payload = WebhookPayload.build(event: "request_submitted", occurrence: "", occurred_at: Time.current,
                                   attributes: ATTRIBUTES.merge(body: "本文", secret: "s3cr3t"))

    assert_not_includes payload.keys, :body
    assert_not_includes payload.keys, :secret
  end

  test "知らない出来事は組み立てない" do
    assert_raises(KeyError) do
      WebhookPayload.build(event: "unknown_event", occurrence: "", occurred_at: Time.current,
                           attributes: ATTRIBUTES)
    end
  end

  private
    def build(event: "request_submitted", occurrence: "", occurred_at: Time.current)
      WebhookPayload.build(event: event, occurrence: occurrence, occurred_at: occurred_at,
                           attributes: ATTRIBUTES)
    end
end
