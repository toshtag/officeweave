require "test_helper"

class AuditEventTest < ActiveSupport::TestCase
  test "記録を残せる" do
    event = AuditEvent.record(organization: organizations(:main), action: "signed_in",
                              actor: users(:taro), target: users(:taro))

    assert_equal "signed_in", event.action
    assert_equal users(:taro), event.actor
  end

  test "操作した利用者が特定できない記録も残せる" do
    event = AuditEvent.record(organization: organizations(:main), action: "sign_in_failed")

    assert_nil event.actor
  end

  test "知らない操作は記録できない" do
    assert_raises(ActiveRecord::RecordInvalid) do
      AuditEvent.record(organization: organizations(:main), action: "unknown_action")
    end
  end

  test "記録は書き換えられない" do
    event = AuditEvent.record(organization: organizations(:main), action: "signed_in", actor: users(:taro))

    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(action: "signed_out") }
  end

  test "記録は削除できない" do
    event = AuditEvent.record(organization: organizations(:main), action: "signed_in", actor: users(:taro))

    assert_raises(ActiveRecord::ReadOnlyRecord) { event.destroy }
  end

  test "操作と利用者で絞り込める" do
    AuditEvent.record(organization: organizations(:main), action: "signed_in", actor: users(:taro))
    AuditEvent.record(organization: organizations(:main), action: "signed_out", actor: users(:hanako))

    assert_equal 1, organizations(:main).audit_events.with_action("signed_in").count
    assert_equal 1, organizations(:main).audit_events.by_actor(users(:hanako).id).count
  end

  test "知らない操作での絞り込みは無視する" do
    AuditEvent.record(organization: organizations(:main), action: "signed_in", actor: users(:taro))

    assert_equal 1, organizations(:main).audit_events.with_action("unknown").count
  end

  test "対象を削除しても記録の内容は残る" do
    department = departments(:development)
    AuditEvent.record(organization: organizations(:main), action: "department_deleted",
                      actor: users(:taro), details: { code: department.code })
    department.destroy

    event = organizations(:main).audit_events.with_action("department_deleted").first

    assert_equal department.code, event.details["code"]
  end

  # 監査記録の一覧と絞り込みは、ACTIONS のすべてを翻訳して並べる。
  # 片方だけ足すと、画面に翻訳の欠落がそのまま出る。
  test "すべての操作に、対応するすべての言語の名前がある" do
    missing = I18n.available_locales.flat_map do |locale|
      AuditEvent::ACTIONS.reject { |action| I18n.exists?("audit_events.actions.#{action}", locale) }
                         .map { |action| "#{locale}: #{action}" }
    end

    assert_empty missing
  end
end
