require "test_helper"

class Officeweave::Configuration::LogFormatTest < ActiveSupport::TestCase
  test "未設定と空文字は行形式として扱う" do
    assert_equal "text", resolve(nil)
    assert_equal "text", resolve("")
  end

  test "受け付ける形式を返す" do
    assert_equal "text", resolve("text")
    assert_equal "json", resolve("json")
  end

  test "知らない形式を拒否する" do
    assert_invalid "JSON"
    assert_invalid "logfmt"
    assert_invalid "json "
    assert_invalid "structured"
  end

  test "拒否する理由に、変数名と受け付ける値を含める" do
    error = assert_raises(Officeweave::Configuration::LogFormat::InvalidLogFormat) { resolve("xml") }

    assert_includes error.message, "LOG_FORMAT"
    assert_includes error.message, "text"
    assert_includes error.message, "json"
  end

  private
    def resolve(raw)
      Officeweave::Configuration::LogFormat.resolve(raw)
    end

    def assert_invalid(raw)
      assert_raises(Officeweave::Configuration::LogFormat::InvalidLogFormat, raw.inspect) { resolve(raw) }
    end
end
