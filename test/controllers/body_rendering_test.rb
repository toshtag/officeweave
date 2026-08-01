require "test_helper"

# 利用者が入力した本文を、画面が平文として描画することを確かめる。
#
# 入力欄は書式を持たない複数行のテキストであり、画面にも文書にも、
# 書式が使えるという説明はない。入力された記号は記号として表示する。
class BodyRenderingTest < ActionDispatch::IntegrationTest
  MARKUP = %(<img src="http://beacon.example/pixel.png"><a href="http://phish.example">規程はこちら</a>).freeze

  setup { sign_in_as users(:taro) }

  test "文書の本文の記号を要素として描画しない" do
    documents(:travel_rule).update!(body: MARKUP)

    get document_url(documents(:travel_rule))

    assert_plain_text_body
  end

  test "お知らせの本文の記号を要素として描画しない" do
    announcements(:company_wide).update!(body: MARKUP)

    get announcement_url(announcements(:company_wide))

    assert_plain_text_body
  end

  test "予定の説明の記号を要素として描画しない" do
    events(:company_meeting).update!(description: MARKUP)

    get event_url(events(:company_meeting))

    assert_plain_text_body
  end

  test "申請の本文の記号を要素として描画しない" do
    requests(:hanako_expense_pending).update!(body: MARKUP)

    get request_url(requests(:hanako_expense_pending))

    assert_plain_text_body
  end

  test "申請の履歴のコメントの記号を要素として描画しない" do
    request_activities(:hanako_expense_submitted).update!(comment: MARKUP)

    get request_url(requests(:hanako_expense_pending))

    assert_plain_text_body
  end

  test "設備・備品の説明の記号を要素として描画しない" do
    resources(:meeting_room_a).update!(description: MARKUP)

    get resource_url(resources(:meeting_room_a))

    assert_plain_text_body
  end

  test "改行は段落と改行として描画する" do
    documents(:travel_rule).update!(body: "一行目\n二行目\n\n次の段落")

    get document_url(documents(:travel_rule))

    assert_select ".prose p", count: 2
    assert_select ".prose p:first-of-type br"
    assert_select ".prose", text: /一行目/
    assert_select ".prose", text: /次の段落/
  end

  private
    # 要素として解釈されていないこと、および入力した記号がそのまま
    # 読めることの両方を確かめる。取り除くだけでは、利用者が入力した
    # 文字が黙って消える。
    def assert_plain_text_body
      assert_response :success

      assert_select ".prose img", count: 0
      assert_select ".prose a", count: 0
      assert_select ".prose", text: /#{Regexp.escape(MARKUP)}/
    end
end
