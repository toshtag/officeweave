require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "記号を要素として解釈しない" do
    result = formatted_body(%(<img src="x.png"><a href="http://outside.example">link</a>))

    assert_equal %(<p>&lt;img src=&quot;x.png&quot;&gt;&lt;a href=&quot;http://outside.example&quot;&gt;link&lt;/a&gt;</p>),
                 result
  end

  test "入力した記号を取り除かない" do
    result = formatted_body("<script>alert(1)</script>")

    assert_includes result, "&lt;script&gt;alert(1)&lt;/script&gt;"
  end

  test "空行で段落を分け、単独の改行を br にする" do
    result = formatted_body("一行目\n二行目\n\n次の段落")

    assert_equal "<p>一行目\n<br />二行目</p>\n\n<p>次の段落</p>", result
  end

  test "改行の表記が CRLF でも同じ結果になる" do
    assert_equal formatted_body("一行目\n二行目"), formatted_body("一行目\r\n二行目")
  end

  test "属性を渡せる" do
    assert_equal %(<p class="prose">本文</p>), formatted_body("本文", class: "prose")
  end

  test "値が無い場合も応答を壊さない" do
    assert_equal "<p></p>", formatted_body(nil)
    assert_equal "<p></p>", formatted_body("")
  end

  # 安全と印の付いた値を素通しすると、渡す側の書き方でこの契約が変わる。
  test "安全と印の付いた値も escape する" do
    result = formatted_body("<b>強調</b>".html_safe)

    assert_equal "<p>&lt;b&gt;強調&lt;/b&gt;</p>", result
  end

  test "描画した結果は安全な文字列として扱える" do
    assert_predicate formatted_body("本文"), :html_safe?
  end
end
