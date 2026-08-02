require "test_helper"

# 配信する内容の出所の制限。
#
# この製品はブラウザーへスクリプトを配信しない（R9-T1）。持ち込まれた
# スクリプトを実行しないことを、応答の側から宣言する。
#
# 宣言だけでは防げないものもある。出力の組み立て（R0-T23 の平文の描画）は
# そのままとし、これはその上に重ねる 1 枚とする。
class ContentSecurityPolicyTest < ActionDispatch::IntegrationTest
  test "画面の応答に方針が付く" do
    get new_session_url

    assert_response :success
    assert response.headers["Content-Security-Policy"].present?
  end

  test "スクリプトの実行を許さない" do
    get new_session_url

    assert_includes policy, "script-src 'none'"
  end

  test "様式と画像は自分の出所だけを許す" do
    get new_session_url

    assert_includes policy, "style-src 'self'"
    assert_includes policy, "img-src 'self' data:"
  end

  test "既定の出所を自分だけに限る" do
    get new_session_url

    assert_includes policy, "default-src 'self'"
  end

  test "送信先を自分だけに限る" do
    # 入力した内容が、別の宛先へ送られる形を防ぐ。
    get new_session_url

    assert_includes policy, "form-action 'self'"
  end

  test "枠へ埋め込ませない" do
    get new_session_url

    assert_includes policy, "frame-ancestors 'none'"
  end

  test "基準の URL と埋め込みの対象を閉じる" do
    get new_session_url

    assert_includes policy, "base-uri 'self'"
    assert_includes policy, "object-src 'none'"
  end

  test "報告だけの設定にしない" do
    # 報告だけでは、実際に読み込まれるものが変わらない。
    get new_session_url

    assert_nil response.headers["Content-Security-Policy-Report-Only"]
  end

  test "ログイン後の画面にも付く" do
    sign_in_as users(:taro)

    get root_url

    assert_response :success
    assert response.headers["Content-Security-Policy"].present?
  end

  test "添付ファイルの応答にも付く" do
    document = organizations(:main).documents.create!(author: users(:taro), title: "手順", body: "本文")
    document.attachments.attach(io: StringIO.new("中身"), filename: "手順.txt", content_type: "text/plain")
    sign_in_as users(:taro)

    get document_attachment_url(document, document.attachments.first)

    assert_response :success
    assert response.headers["Content-Security-Policy"].present?
  end

  test "API の応答では方針を付けない" do
    # 方針はブラウザーの読み込みに効く。API の応答には意味を持たない。
    token = users(:taro).api_tokens.create!(organization: organizations(:main), name: "検証", scopes: nil)

    get api_v1_announcements_url, headers: { "Authorization" => "Bearer #{token.token}" }

    assert_response :success
    assert_nil response.headers["Content-Security-Policy"]
  end

  private
    def policy = response.headers["Content-Security-Policy"].to_s
end
