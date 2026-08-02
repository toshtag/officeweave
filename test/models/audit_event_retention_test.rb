require "test_helper"

# 監査記録の保持期間。
#
# 記録は書き足すだけとし、個々の記録を消す経路は持たない。
# 唯一の例外として、保持期間より古い記録だけを、定期実行がまとめて消す。
# 消す範囲を取り違えると、失われたことを後から確かめられない。
class AuditEventRetentionTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:main)
    AuditEvent.delete_all
  end

  test "保持期間を指定しなければ何も消さない" do
    record(created_at: 10.years.ago)

    with_retention(nil) { assert_equal 0, AuditEvent.delete_expired }

    assert_equal 1, AuditEvent.count
  end

  test "保持期間より古い記録を消す" do
    old = record(created_at: 31.days.ago)
    recent = record(created_at: 29.days.ago)

    with_retention("30") { assert_equal 1, AuditEvent.delete_expired }

    assert_equal [ recent.id ], AuditEvent.pluck(:id)
    refute AuditEvent.exists?(old.id)
  end

  test "境界の時刻ちょうどは残す" do
    at = Time.current
    boundary = record(created_at: at - 30.days)

    with_retention("30") { AuditEvent.delete_expired(at: at) }

    assert AuditEvent.exists?(boundary.id), "保持期間の内側にある記録を消している"
  end

  test "組織をまたいで同じ基準で消す" do
    other = organizations(:other)
    mine = record(created_at: 31.days.ago)
    theirs = record(organization: other, created_at: 31.days.ago)

    with_retention("30") { AuditEvent.delete_expired }

    refute AuditEvent.exists?(mine.id)
    refute AuditEvent.exists?(theirs.id), "他の組織の古い記録が残っている"
  end

  test "書き換えを禁じる仕掛けに阻まれずに消す" do
    # 記録は before_destroy で削除を拒む。保持期間の削除は、その経路を通らない。
    record(created_at: 31.days.ago)

    with_retention("30") do
      assert_nothing_raised { AuditEvent.delete_expired }
    end

    assert_equal 0, AuditEvent.count
  end

  test "個々の記録を消す経路は残らない" do
    event = record(created_at: 31.days.ago)

    assert_raises(ActiveRecord::ReadOnlyRecord) { event.destroy }
  end

  test "保持期間の内側だけを数えられる" do
    record(created_at: 31.days.ago)
    record(created_at: 29.days.ago)

    with_retention("30") { assert_equal 1, AuditEvent.expired.count }
  end

  private
    def record(organization: @organization, created_at:)
      AuditEvent.create!(organization: organization, action: "signed_in", created_at: created_at)
    end

    # 設定は起動時に解決する。テストの中では、その結果だけを差し替える。
    def with_retention(days)
      previous = ENV["AUDIT_RETENTION_DAYS"]
      ENV["AUDIT_RETENTION_DAYS"] = days
      yield
    ensure
      ENV["AUDIT_RETENTION_DAYS"] = previous
    end
end
