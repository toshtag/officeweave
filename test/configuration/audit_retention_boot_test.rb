require "test_helper"

# 監査記録の保持期間の設定そのものの検査。
#
# 既に起動しているテストプロセスの中で値を読んでも、「起動しない」ことは
# 確かめられない。別のプロセスを実際に起動し、終了状態と出力を外側から見る。
#
# 誤った値を「指定なし」として扱うと、保持しているつもりの組織で記録が
# 消え続け、あるいは消しているつもりの組織で溜まり続ける。
# どちらも気付くのは後になる。起動の時点で止める。
class AuditRetentionBootTest < ActiveSupport::TestCase
  include BootProcessTestHelper

  test "設定が無い場合は起動し、消さない状態になる" do
    status, output = boot(nil)

    assert_predicate status, :success?, output
    assert_includes output, "BOOTED:none"
  end

  test "日数を指定した場合は起動する" do
    status, output = boot("365")

    assert_predicate status, :success?, output
    assert_includes output, "BOOTED:365"
  end

  test "整数でない値が指定された場合は起動しない" do
    status, output = boot("いつまでも")

    assert_not_predicate status, :success?, output
    assert_not_includes output, "BOOTED:"
    assert_includes output, "AUDIT_RETENTION_DAYS"
    assert_includes output, "いつまでも"
  end

  test "0 が指定された場合は起動しない" do
    # 「0 日で消す」を受け付けると、書き足した記録がその日のうちに消える。
    status, output = boot("0")

    assert_not_predicate status, :success?, output
    assert_not_includes output, "BOOTED:"
    assert_includes output, "AUDIT_RETENTION_DAYS"
  end

  test "空文字が指定された場合は消さない状態で起動する" do
    # 空文字は「設定していない」ことの表し方として、他の変数と同じに扱う。
    status, output = boot("")

    assert_predicate status, :success?, output
    assert_includes output, "BOOTED:none"
  end

  private
    RESOLVE = 'puts "BOOTED:#{Officeweave::Configuration::AuditRetention.days || "none"}"'

    # nil を渡した場合は、環境変数そのものを子プロセスへ渡さない。
    def boot(days)
      environment = { "RAILS_ENV" => "test", "AUDIT_RETENTION_DAYS" => days }

      # シェルを介さず引数のまま渡す。設定値が語の区切りとして解釈されない。
      boot_process([ "bin/rails", "runner", RESOLVE ], environment)
    end
end
