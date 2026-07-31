require "test_helper"

class Officeweave::Configuration::ApplicationPortTest < ActiveSupport::TestCase
  test "未設定と空文字は指定しないものとして扱う" do
    assert_nil resolve(nil)
    assert_nil resolve("")
  end

  test "整数として解釈した値を返す" do
    assert_equal 3210, resolve("3210")
    assert_equal 1, resolve("1")
    assert_equal 65_535, resolve("65535")
  end

  test "範囲の外を拒否する" do
    assert_invalid "0"
    assert_invalid "65536"
    assert_invalid "99999"
  end

  test "整数でない値を拒否する" do
    assert_invalid "-1"
    assert_invalid "+3210"
    assert_invalid "32.10"
    assert_invalid "3210/"
    assert_invalid "http"
  end

  test "前後に空白がある値を取り除かずに拒否する" do
    assert_invalid " 3210"
    assert_invalid "3210 "
  end

  test "先頭に 0 が付く値を補正せずに拒否する" do
    assert_invalid "03210"
  end

  test "拒否の理由には環境変数名と指定値だけを載せる" do
    error = assert_raises(Officeweave::Configuration::ApplicationPort::InvalidApplicationPort) do
      resolve("65536")
    end

    assert_includes error.message, "APPLICATION_PORT"
    assert_includes error.message, %("65536")
    assert_includes error.message, "65535"
  end

  private
    def resolve(raw)
      Officeweave::Configuration::ApplicationPort.resolve(raw)
    end

    def assert_invalid(raw)
      assert_raises(Officeweave::Configuration::ApplicationPort::InvalidApplicationPort, raw.inspect) do
        resolve(raw)
      end
    end
end
