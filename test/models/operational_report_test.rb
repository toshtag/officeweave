require "test_helper"

# 運用者へ知らせる異常の選び方。
#
# 毎日届く通知は読まれなくなる。知らせるのは、放っておくと運用が
# 成り立たなくなるものだけとする。判断の元は運用診断とし、
# 同じことを 2 か所で判定しない。
class OperationalReportTest < ActiveSupport::TestCase
  test "診断の失敗はすべて知らせる" do
    report = build([
      { name: "データベースへの接続", status: :error, detail: "接続できません", notify: true },
      { name: "署名に使う鍵", status: :ok, detail: "設定されています", notify: false }
    ])

    assert_predicate report, :any?
    assert_equal [ "データベースへの接続" ], report.issues.map { |issue| issue[:name] }
  end

  test "知らせる印の付いた注意も含める" do
    report = build([
      { name: "失敗したジョブ", status: :warning, detail: "3 件あります", notify: true }
    ])

    assert_equal [ "失敗したジョブ" ], report.issues.map { |issue| issue[:name] }
  end

  test "印の無い注意は含めない" do
    # 設定として選んだ結果の注意は、毎日知らせても行動が変わらない。
    report = build([
      { name: "Webhook の内部宛先の許可", status: :warning, detail: "1 件の origin", notify: false }
    ])

    refute_predicate report, :any?
    assert_empty report.issues
  end

  test "異常が無ければ知らせるものを持たない" do
    report = build([ { name: "データベースへの接続", status: :ok, detail: nil, notify: false } ])

    refute_predicate report, :any?
  end

  test "実際の診断からも組み立てられる" do
    report = OperationalReport.new

    # 手元の構成では失敗しない。項目の形だけを確かめる。
    report.issues.each do |issue|
      assert issue[:name].present?
      assert_includes %i[error warning], issue[:status]
    end
  end

  private
    def build(checks)
      OperationalReport.new(checks: checks)
    end
end
