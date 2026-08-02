require "test_helper"
require "csv"

# 監査記録の書き出しの経路。
#
# 記録には、誰がいつ何をしたかが入る。参照と同じ範囲へ限る。
class AuditEventsExportTest < ActionDispatch::IntegrationTest
  setup do
    AuditEvent.delete_all
  end

  test "管理者は書き出せる" do
    AuditEvent.record(organization: organizations(:main), action: "signed_in", actor: users(:taro))
    sign_in_as users(:taro)

    get export_audit_events_url(format: :csv)

    assert_response :success
    assert_equal "text/csv; charset=utf-8", response.media_type + "; charset=utf-8"
    assert_match(/attachment; filename="audit-events-\d{4}-\d{2}-\d{2}\.csv"/,
                 response.headers["Content-Disposition"])
    assert_equal %w[signed_in], CSV.parse(response.body, headers: true).map { |row| row["action"] }
  end

  test "一般利用者は書き出せない" do
    sign_in_as users(:hanako)

    get export_audit_events_url(format: :csv)

    # 参照と同じ扱いにする。権限が無いことは、経路の有無ではなく応答で示す。
    assert_response :forbidden
  end

  test "ログインしていなければ書き出せない" do
    get export_audit_events_url(format: :csv)

    assert_redirected_to new_session_path
  end

  test "他の組織の記録は書き出さない" do
    AuditEvent.record(organization: organizations(:other), action: "signed_in")
    sign_in_as users(:taro)

    get export_audit_events_url(format: :csv)

    assert_empty CSV.parse(response.body, headers: true).to_a[1..] || []
  end

  test "画面と同じ絞り込みで書き出す" do
    AuditEvent.record(organization: organizations(:main), action: "signed_in", actor: users(:taro))
    AuditEvent.record(organization: organizations(:main), action: "signed_out", actor: users(:hanako))
    sign_in_as users(:taro)

    get export_audit_events_url(format: :csv, audit_action: "signed_out")

    assert_equal %w[signed_out], CSV.parse(response.body, headers: true).map { |row| row["action"] }
  end

  test "書き出したことを記録へ残す" do
    AuditEvent.record(organization: organizations(:main), action: "signed_in", actor: users(:taro))
    sign_in_as users(:taro)

    assert_difference -> { AuditEvent.with_action("audit_events_exported").count }, 1 do
      get export_audit_events_url(format: :csv)
    end

    event = AuditEvent.with_action("audit_events_exported").recent_first.first

    assert_equal users(:taro), event.actor
    # 何件を持ち出したかが分からないと、後から範囲を確かめられない。
    assert_equal 1, event.details["count"]
  end

  test "上限を超える件数は、切り詰めずに拒否する" do
    stub_const(AuditEventsController, :EXPORT_LIMIT, 1) do
      2.times { AuditEvent.record(organization: organizations(:main), action: "signed_in") }
      sign_in_as users(:taro)

      get export_audit_events_url(format: :csv)

      assert_redirected_to audit_events_path
      assert_match(/1/, flash[:alert])
    end
  end

  test "上限を超えた場合は、書き出しとして記録しない" do
    stub_const(AuditEventsController, :EXPORT_LIMIT, 1) do
      2.times { AuditEvent.record(organization: organizations(:main), action: "signed_in") }
      sign_in_as users(:taro)

      assert_no_difference -> { AuditEvent.with_action("audit_events_exported").count } do
        get export_audit_events_url(format: :csv)
      end
    end
  end

  test "一覧の画面から書き出しへ行ける" do
    sign_in_as users(:taro)

    get audit_events_url(audit_action: "signed_in")

    assert_response :success
    # 絞り込みを引き継ぐ。引き継がないと、画面で絞った結果と別のものが出る。
    assert_select "a[href=?]", export_audit_events_path(format: :csv, audit_action: "signed_in")
  end

  private
    # 上限そのものを大きな件数で確かめると、確かめたい分岐に対して
    # 用意する記録が多すぎる。上限の値だけを差し替える。
    def stub_const(owner, name, value)
      original = owner.const_get(name)
      owner.send(:remove_const, name)
      owner.const_set(name, value)
      yield
    ensure
      owner.send(:remove_const, name)
      owner.const_set(name, original)
    end
end
