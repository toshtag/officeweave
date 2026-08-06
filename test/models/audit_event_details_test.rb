require "test_helper"

# 監査の詳細に置く値。
#
# 監査は、誰が何をしたかを追うためのものであり、業務の内容の写しではない。
# 本文やコメントを写すと、記録の側に別の保持期間と別の読み手を持つ複製が
# できる。秘密や token を写せば、監査を読める相手がそのまま使える。
class AuditEventDetailsTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:main)
    @actor = users(:taro)
  end

  test "秘密と token の鍵は取り除く" do
    event = record(details: { name: "連携", token: "abc123", secret: "s3cr3t", password: "p@ss" })

    assert_equal "連携", event.details["name"]
    assert_equal AuditEvent::REDACTED, event.details["token"]
    assert_equal AuditEvent::REDACTED, event.details["secret"]
    assert_equal AuditEvent::REDACTED, event.details["password"]
  end

  test "本文とコメントの鍵は取り除く" do
    event = record(details: { body: "申請の本文", comment: "差し戻しの理由", description: "説明" })

    assert_equal [ AuditEvent::REDACTED ] * 3, event.details.values_at("body", "comment", "description")
  end

  test "鍵の名前は大文字と小文字を区別しない" do
    event = record(details: { "Token" => "abc", "API_SECRET" => "def" })

    assert_equal [ AuditEvent::REDACTED, AuditEvent::REDACTED ], event.details.values_at("Token", "API_SECRET")
  end

  test "部分一致でも取り除く" do
    event = record(details: { webhook_secret: "abc", access_token: "def", user_password_digest: "ghi" })

    assert_equal [ AuditEvent::REDACTED ] * 3,
                 event.details.values_at("webhook_secret", "access_token", "user_password_digest")
  end

  test "入れ子の中も同じ規則で見る" do
    # 1 段目だけを見ると、まとめた鍵の下へ置くだけで通り抜ける。
    event = record(details: { changes: { token: "abc", url: "https://example.com/hook" } })

    assert_equal AuditEvent::REDACTED, event.details.dig("changes", "token")
    assert_equal "https://example.com/hook", event.details.dig("changes", "url")
  end

  test "配列の中も同じ規則で見る" do
    event = record(details: { entries: [ { secret: "abc" }, { code: "sales" } ] })

    assert_equal AuditEvent::REDACTED, event.details["entries"][0]["secret"]
    assert_equal "sales", event.details["entries"][1]["code"]
  end

  test "長い値は切り詰める" do
    # 鍵の名前だけでは、自由に書ける文章が別の名前で入ってくるのを止められない。
    event = record(details: { title: "あ" * 500 })

    assert_equal AuditEvent::MAXIMUM_DETAIL_LENGTH + AuditEvent::TRUNCATED.length, event.details["title"].length
    assert event.details["title"].end_with?(AuditEvent::TRUNCATED)
  end

  test "上限のちょうどの長さは切り詰めない" do
    value = "あ" * AuditEvent::MAXIMUM_DETAIL_LENGTH
    event = record(details: { title: value })

    assert_equal value, event.details["title"]
  end

  test "識別に使う短い値はそのまま残す" do
    event = record(details: { code: "sales", count: 12, email_address: "taro@example.com", active: true })

    assert_equal({ "code" => "sales", "count" => 12, "email_address" => "taro@example.com", "active" => true },
                 event.details)
  end

  test "詳細を持たない記録も作れる" do
    assert_empty record(details: {}).details
  end

  # 保存の直前で取り除く。書く側の判断に任せると、書く場所が増えるたびに
  # 同じ判断をやり直すことになる。
  test "記録の入口を通らない作成でも取り除く" do
    event = AuditEvent.create!(organization: @organization, actor: @actor, action: "signed_in",
                               details: { token: "abc" })

    assert_equal AuditEvent::REDACTED, event.details["token"]
  end

  private
    def record(details:)
      AuditEvent.record(organization: @organization, actor: @actor, action: "signed_in", details: details)
    end
end
