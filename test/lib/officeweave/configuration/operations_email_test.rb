require "test_helper"

class Officeweave::Configuration::OperationsEmailTest < ActiveSupport::TestCase
  test "未設定と空文字は知らせないものとして扱う" do
    assert_nil resolve(nil)
    assert_nil resolve("")
  end

  test "宛先をそのまま返す" do
    assert_equal "ops@example.com", resolve("ops@example.com")
  end

  test "宛先として使えない値を拒否する" do
    assert_invalid "ops"
    assert_invalid "ops@"
    assert_invalid "@example.com"
    assert_invalid "ops example@example.com"
    assert_invalid " ops@example.com"
    assert_invalid "ops@example.com,admin@example.com"
  end

  test "拒否する理由に、変数名と指定しない場合の扱いを含める" do
    error = assert_raises(Officeweave::Configuration::OperationsEmail::InvalidOperationsEmail) do
      resolve("担当者")
    end

    assert_includes error.message, "OPERATIONS_EMAIL"
    assert_includes error.message, "知らせません"
  end

  private
    def resolve(raw)
      Officeweave::Configuration::OperationsEmail.resolve(raw)
    end

    def assert_invalid(raw)
      assert_raises(Officeweave::Configuration::OperationsEmail::InvalidOperationsEmail, raw.inspect) do
        resolve(raw)
      end
    end
end
