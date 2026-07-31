require "test_helper"

class Authentication::LocalPathTest < ActiveSupport::TestCase
  test "アプリケーション内の絶対パスを認める" do
    [ "/", "/documents", "/requests/12", "/documents?query=manual" ].each do |candidate|
      assert_equal candidate, permitted(candidate)
    end
  end

  test "完全 URL を認めない" do
    assert_nil permitted("https://outside.example/path")
    assert_nil permitted("http://outside.example/path")
  end

  test "プロトコル相対の値を認めない" do
    assert_nil permitted("//outside.example/path")
  end

  test "逆斜線を含む値を認めない" do
    assert_nil permitted("/\\outside.example/path")
    assert_nil permitted("/documents\\..\\outside.example")
  end

  test "斜線から始まらない値を認めない" do
    assert_nil permitted("outside.example/path")
    assert_nil permitted("documents")
  end

  test "空文字を認めない" do
    assert_nil permitted("")
  end

  test "制御文字を含む値を認めない" do
    assert_nil permitted("/documents\nSet-Cookie: injected=1")
    assert_nil permitted("/documents\r\nLocation: https://outside.example")
    assert_nil permitted("/documents\tmore")
  end

  test "フラグメントを含む値を認めない" do
    assert_nil permitted("/documents#section")
  end

  test "解釈できない値では例外を出さずに拒否する" do
    assert_nil permitted("/documents/[")
    assert_nil permitted("/documents/%zz")
    assert_nil permitted("/docu ments")
  end

  test "文字列でない値を認めない" do
    assert_nil permitted(nil)
    assert_nil permitted(:root)
    assert_nil permitted([ "/documents" ])
  end

  private
    def permitted(candidate)
      Authentication::LocalPath.permitted(candidate)
    end
end
