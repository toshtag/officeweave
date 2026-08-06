require "test_helper"

# 運用の異常を知らせた記録。
#
# 送ったかどうかを残さないと、定期実行が二度動いたときに同じ内容が二度届き、
# 届いていないと思っても確かめる先が無い。
class OperationalAlertTest < ActiveSupport::TestCase
  OCCURRENCE = "a-known-occurrence".freeze

  test "はじめての発生は知らせる" do
    assert OperationalAlert.claim(OCCURRENCE)
    assert_equal 1, OperationalAlert.where(occurrence: OCCURRENCE).count
  end

  test "同じ発生が続くあいだは知らせ直さない" do
    OperationalAlert.claim(OCCURRENCE)

    assert_not OperationalAlert.claim(OCCURRENCE)
    assert_equal 1, OperationalAlert.where(occurrence: OCCURRENCE).count
  end

  test "間隔を過ぎれば知らせ直す" do
    at = Time.current
    OperationalAlert.claim(OCCURRENCE, at: at)

    assert OperationalAlert.claim(OCCURRENCE, at: at + OperationalAlert::REMINDER_INTERVAL + 1.second)
  end

  test "間隔のちょうどでは、まだ知らせ直さない" do
    at = Time.current
    OperationalAlert.claim(OCCURRENCE, at: at)

    assert_not OperationalAlert.claim(OCCURRENCE, at: at + OperationalAlert::REMINDER_INTERVAL)
  end

  test "知らせ直しても記録は 1 件のままとする" do
    at = Time.current
    OperationalAlert.claim(OCCURRENCE, at: at)
    later = at + OperationalAlert::REMINDER_INTERVAL + 1.second
    OperationalAlert.claim(OCCURRENCE, at: later)

    assert_equal 1, OperationalAlert.where(occurrence: OCCURRENCE).count
    assert_in_delta later, OperationalAlert.find_by(occurrence: OCCURRENCE).sent_at, 1.second
  end

  test "別の発生は別の記録として残す" do
    OperationalAlert.claim(OCCURRENCE)

    assert OperationalAlert.claim("another-occurrence")
    assert_equal 2, OperationalAlert.count
  end

  test "発生を表す値は必須とする" do
    assert_not OperationalAlert.new(sent_at: Time.current).valid?
  end

  test "異常の組が同じなら、発生を表す値も同じになる" do
    checks = [ { name: "ジョブの実行", status: :warning, detail: "いま 3 件", notify: true } ]
    later = [ { name: "ジョブの実行", status: :warning, detail: "いま 812 件", notify: true } ]

    # 詳細の文面は入れない。件数や時刻が入り、内容が変わっていなくても
    # 毎回違う値になる。
    assert_equal OperationalReport.new(checks: checks).occurrence,
                 OperationalReport.new(checks: later).occurrence
  end

  test "異常が増えれば、発生を表す値も変わる" do
    one = [ { name: "ジョブの実行", status: :warning, detail: "", notify: true } ]
    two = one + [ { name: "メールの送信", status: :error, detail: "", notify: true } ]

    assert_not_equal OperationalReport.new(checks: one).occurrence,
                     OperationalReport.new(checks: two).occurrence
  end

  test "並び順が違っても、発生を表す値は同じになる" do
    one = [ { name: "あ", status: :error, detail: "", notify: true },
            { name: "い", status: :error, detail: "", notify: true } ]

    assert_equal OperationalReport.new(checks: one).occurrence,
                 OperationalReport.new(checks: one.reverse).occurrence
  end

  test "知らせない印の付いた確認は、発生を表す値に入れない" do
    quiet = [ { name: "ジョブの実行", status: :ok, detail: "", notify: false } ]
    none = []

    assert_equal OperationalReport.new(checks: none).occurrence,
                 OperationalReport.new(checks: quiet).occurrence
  end
end
