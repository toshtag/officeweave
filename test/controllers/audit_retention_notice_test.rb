require "test_helper"

# 監査記録の画面が、保持期間を管理者へ伝えることを固定する。
#
# 記録が消える設定になっていることは、画面からは分からない。
# 分からないまま運用すると、過去の記録を探したときに初めて気付く。
class AuditRetentionNoticeTest < ActionDispatch::IntegrationTest
  teardown do
    ENV.delete("AUDIT_RETENTION_DAYS")
  end

  test "保持期間を指定していれば、日数を示す" do
    ENV["AUDIT_RETENTION_DAYS"] = "365"
    sign_in_as users(:taro)

    get audit_events_url

    assert_response :success
    assert_select "[data-audit-retention]", text: /365/
  end

  test "保持期間を指定していなければ、消えないことを示す" do
    sign_in_as users(:taro)

    get audit_events_url

    assert_response :success
    assert_select "[data-audit-retention]", text: /消えません/
  end
end
