require "test_helper"

# 一覧が読み込む期間。
#
# 始まりだけを受け取る形では、蓄積した記録がそのまま読み込む量になる。
# 期間の長さにも上限が要る。利用者が終わりを遠くへ指定すれば同じことが起きる。
class DateWindowTest < ActiveSupport::TestCase
  TODAY = Date.new(2026, 8, 6)

  test "指定が無ければ今日から既定の日数を見る" do
    window = DateWindow.new(today: TODAY)

    assert_equal TODAY, window.from
    assert_equal TODAY + DateWindow::DEFAULT_DAYS, window.to
    assert_not_predicate window, :truncated?
  end

  test "始まりと終わりを指定できる" do
    window = DateWindow.new(from: TODAY, to: TODAY + 10, today: TODAY)

    assert_equal TODAY + 10, window.to
    assert_not_predicate window, :truncated?
  end

  test "期間の長さは上限で切り詰める" do
    window = DateWindow.new(from: TODAY, to: TODAY + 10_000, today: TODAY)

    assert_equal TODAY + DateWindow::MAXIMUM_DAYS, window.to
    assert_predicate window, :truncated?
  end

  test "上限のちょうどは切り詰めない" do
    window = DateWindow.new(from: TODAY, to: TODAY + DateWindow::MAXIMUM_DAYS, today: TODAY)

    assert_not_predicate window, :truncated?
  end

  test "始まりより前の終わりは、その日 1 日として扱う" do
    # 誤りとして拒むと、日付を入れ替えている途中の操作が失敗する。
    window = DateWindow.new(from: TODAY, to: TODAY - 10, today: TODAY)

    assert_equal TODAY, window.from
    assert_equal TODAY, window.to
  end

  test "終わりの日を含む範囲を返す" do
    window = DateWindow.new(from: TODAY, to: TODAY + 3, today: TODAY)

    assert_equal TODAY..(TODAY + 3), window.covers
  end
end
