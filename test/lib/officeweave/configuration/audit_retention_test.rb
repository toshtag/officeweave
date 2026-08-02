require "test_helper"

class Officeweave::Configuration::AuditRetentionTest < ActiveSupport::TestCase
  test "未設定と空文字は消さないものとして扱う" do
    assert_nil resolve(nil)
    assert_nil resolve("")
  end

  test "整数として解釈した日数を返す" do
    assert_equal 1, resolve("1")
    assert_equal 365, resolve("365")
  end

  test "1 より小さい値を拒否する" do
    assert_invalid "0"
    assert_invalid "-1"
  end

  test "整数でない値を拒否する" do
    assert_invalid "365.5"
    assert_invalid "1 year"
    assert_invalid "+365"
    assert_invalid "３６５"
  end

  test "先頭に 0 が付いた値を拒否する" do
    # 補正すると、設定に書いた値と実際に働く日数が食い違う。
    assert_invalid "0365"
  end

  test "拒否する理由に、変数名と指定しない場合の扱いを含める" do
    error = assert_raises(Officeweave::Configuration::AuditRetention::InvalidAuditRetention) do
      resolve("いつまでも")
    end

    assert_includes error.message, "AUDIT_RETENTION_DAYS"
    assert_includes error.message, "消しません"
  end

  private
    def resolve(raw)
      Officeweave::Configuration::AuditRetention.resolve(raw)
    end

    def assert_invalid(raw)
      assert_raises(Officeweave::Configuration::AuditRetention::InvalidAuditRetention, raw.inspect) do
        resolve(raw)
      end
    end
end
