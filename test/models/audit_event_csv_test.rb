require "test_helper"
require "csv"
require "stringio"

# 監査記録の書き出し。
#
# 書き出したものは、組織の外へ渡ることがある。保持期間で消えた後は、
# これが唯一の控えになる。列の並びと値の形を固定する。
class AuditEventCsvTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:main)
    AuditEvent.delete_all
  end

  test "列の並びを固定する" do
    assert_equal %w[
      organization_code
      recorded_at
      action
      actor_name
      actor_email_address
      target_type
      target_id
      ip_address
      details
    ], AuditEventCsv::HEADERS
  end

  test "記録を古い順に書き出す" do
    older = record(action: "signed_in", created_at: 2.days.ago)
    newer = record(action: "signed_out", created_at: 1.day.ago)

    rows = parse(AuditEventCsv.new(@organization.audit_events).export)

    assert_equal %w[signed_in signed_out], rows.map { |row| row["action"] }
    assert_equal [ older, newer ].map { |event| event.created_at.utc.iso8601 },
                 rows.map { |row| row["recorded_at"] }
  end

  test "操作の名前は翻訳せずに書き出す" do
    record(action: "signed_in")

    I18n.with_locale(:en) do
      assert_equal "signed_in", parse(AuditEventCsv.new(@organization.audit_events).export).first["action"]
    end
  end

  test "操作した利用者と対象を書き出す" do
    record(action: "user_updated", actor: users(:taro), target: users(:hanako), ip_address: "192.0.2.10")

    row = parse(AuditEventCsv.new(@organization.audit_events).export).first

    assert_equal "main", row["organization_code"]
    assert_equal users(:taro).name, row["actor_name"]
    assert_equal users(:taro).email_address, row["actor_email_address"]
    assert_equal "User", row["target_type"]
    assert_equal users(:hanako).id.to_s, row["target_id"]
    assert_equal "192.0.2.10", row["ip_address"]
  end

  test "操作した利用者が特定できない記録も書き出す" do
    record(action: "sign_in_failed")

    row = parse(AuditEventCsv.new(@organization.audit_events).export).first

    # 値は必ず引用して書き出す。空欄は空文字として戻る。
    assert_empty row["actor_name"]
    assert_empty row["actor_email_address"]
  end

  test "内訳は JSON として書き出す" do
    record(action: "users_imported", details: { created: 2, updated: 1 })

    row = parse(AuditEventCsv.new(@organization.audit_events).export).first

    assert_equal({ "created" => 2, "updated" => 1 }, JSON.parse(row["details"]))
  end

  test "数式として解釈され得る値を保護する" do
    # 利用者名は記号を制限していない。書き出した先で数式として評価させない。
    actor = @organization.users.create!(
      name: "=1+1", email_address: "formula@example.com", password: "a-long-secret-value"
    )
    record(action: "signed_in", actor: actor)

    row = parse(AuditEventCsv.new(@organization.audit_events).export).first

    refute_match(/\A=/, row["actor_name"])
    assert_equal "'=1+1", row["actor_name"]
  end

  test "渡された絞り込みをそのまま使う" do
    record(action: "signed_in")
    record(action: "signed_out")

    rows = parse(AuditEventCsv.new(@organization.audit_events.with_action("signed_out")).export)

    assert_equal %w[signed_out], rows.map { |row| row["action"] }
  end

  test "組織をまたぐ書き出しでは、どの組織の記録かが残る" do
    record(action: "signed_in")
    record(action: "signed_in", organization: organizations(:other))

    rows = parse(AuditEventCsv.new(AuditEvent.all).export)

    assert_equal %w[main other].sort, rows.map { |row| row["organization_code"] }.sort
  end

  test "書き出し先へ流し込める" do
    record(action: "signed_in")
    buffer = StringIO.new

    AuditEventCsv.new(@organization.audit_events).write(buffer)

    assert_equal AuditEventCsv.new(@organization.audit_events).export, buffer.string
  end

  test "流し込みでは、件数の分だけ読み込みを分ける" do
    3.times { record(action: "signed_in") }
    queries = 0
    subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
      queries += 1 if payload[:sql].include?("audit_events")
    end

    AuditEventCsv.new(@organization.audit_events, batch_size: 1).write(StringIO.new)

    # 1 件ずつ読む指定であれば、まとめて 1 回では読まない。
    assert_operator queries, :>=, 3
  ensure
    ActiveSupport::Notifications.unsubscribe(subscription)
  end

  private
    def record(action:, organization: @organization, **attributes)
      AuditEvent.create!(organization: organization, action: action, **attributes)
    end

    def parse(content)
      CSV.parse(content, headers: true)
    end
end
