require "test_helper"

# 別のプロセスの起動を待つ仕組みそのものの検査。
#
# 実際の設定を確かめるテストは、起動が終わる前提で書かれている。
# 終わらなかった場合にどう受け取るかは、ここで固定する。
class BootProcessTest < ActiveSupport::TestCase
  include BootProcessTestHelper

  test "終了した場合は終了状態と出力を返す" do
    status, output = boot_process([ "sh", "-c", "echo 起動しました" ], {})

    assert_predicate status, :success?
    assert_includes output, "起動しました"
  end

  test "異常終了した場合も終了状態と出力を返す" do
    status, output = boot_process([ "sh", "-c", "echo 設定が誤っています >&2; exit 1" ], {})

    assert_not_predicate status, :success?
    assert_includes output, "設定が誤っています"
  end

  # 何秒待ったかだけでは、起動しなかったのか遅かったのかを判別できない。
  test "上限に達した場合はそこまでの出力を添えて失敗する" do
    error = assert_raises(Minitest::Assertion) do
      boot_process([ "sh", "-c", "echo 途中まで進みました; sleep 60" ], {}, timeout: 2)
    end

    assert_match(/途中まで進みました/, error.message)
  end

  test "出力が無いまま上限に達した場合も、そのことを示す" do
    error = assert_raises(Minitest::Assertion) do
      boot_process([ "sh", "-c", "sleep 60" ], {}, timeout: 2)
    end

    assert_match(/出力もありませんでした/, error.message)
  end
end
