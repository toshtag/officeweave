require "test_helper"

# 添付ファイルの取得。
#
# 取得できる経路は文書の配下の一つだけとし、取得のたびに参照範囲を見る。
# 署名付きの ID を知っていることを、参照できる根拠にしない。
class AttachmentDeliveryTest < ActionDispatch::IntegrationTest
  setup do
    @document = documents(:travel_rule)
    @document.attachments.attach(io: StringIO.new("本文"), filename: "手順書.txt", content_type: "text/plain")
    @attachment = @document.attachments.reload.first
  end

  test "参照できる利用者は元のファイルをそのまま受け取る" do
    sign_in_as users(:hanako)

    get document_attachment_url(@document, @attachment)

    assert_response :success
    # 応答は byte 列で返るため、符号化を揃えて比べる。
    assert_equal "本文".b, response.body
    assert_equal "text/plain", response.media_type
    assert_match "attachment", response.headers["Content-Disposition"]
    assert_match "手順書.txt", CGI.unescape(response.headers["Content-Disposition"])
  end

  test "作成者は公開範囲の外にいても取得できる" do
    document = Document.create!(organization: organizations(:main), author: users(:hanako),
                                title: "開発部だけの手引き", visibility: "departments",
                                departments: [ departments(:development) ])
    document.attachments.attach(io: StringIO.new("a"), filename: "note.txt", content_type: "text/plain")

    sign_in_as users(:hanako)

    get document_attachment_url(document, document.attachments.reload.first)

    assert_response :success
  end

  test "別組織の利用者は取得できない" do
    sign_in_as users(:outsider)

    get document_attachment_url(@document, @attachment)

    assert_response :not_found
  end

  test "別の文書の添付を組み合わせても取得できない" do
    other = documents(:sales_only_document)
    other.attachments.attach(io: StringIO.new("b"), filename: "secret.txt", content_type: "text/plain")

    sign_in_as users(:hanako)

    get document_attachment_url(@document, other.attachments.reload.first)

    assert_response :not_found
  end

  test "存在しない添付は取得できない" do
    sign_in_as users(:hanako)
    id = @attachment.id
    @document.attachments.first.purge

    get document_attachment_url(@document, id)

    assert_response :not_found
  end

  test "公開範囲を狭めると同じ URL から取得できなくなる" do
    sign_in_as users(:hanako)
    url = document_attachment_url(@document, @attachment)

    get url

    assert_response :success

    @document.update!(visibility: "departments", departments: [ departments(:sales) ])

    get url

    assert_response :not_found
  end

  test "保存基盤の経路は未ログインでも取得できない" do
    standard_paths.each do |path|
      get path

      assert_response :not_found, "#{path} へ到達した"
    end
  end

  test "保存基盤の経路はログインしていても取得できない" do
    sign_in_as users(:hanako)

    standard_paths.each do |path|
      get path

      assert_response :not_found, "#{path} へ到達した"
    end
  end

  test "保存基盤の経路は管理者でも取得できない" do
    sign_in_as users(:taro)

    assert_predicate users(:taro), :administrator?

    standard_paths.each do |path|
      get path

      assert_response :not_found, "#{path} へ到達した"
    end
  end

  test "保存基盤への直接の受け付け口がない" do
    sign_in_as users(:taro)

    post "/rails/active_storage/direct_uploads",
         params: { blob: { filename: "a.txt", byte_size: 1, checksum: "x", content_type: "text/plain" } }

    assert_response :not_found
  end

  test "画面の添付リンクは文書の配下の経路を指す" do
    sign_in_as users(:hanako)

    get document_url(@document)

    assert_response :success
    assert_select "a[href=?]", document_attachment_path(@document, @attachment)
    assert_no_match %r{/rails/active_storage}, response.body
    assert_no_match Regexp.new(Regexp.escape(@attachment.blob.signed_id)), response.body
  end

  private
    # 保存基盤が作っていた経路。helper がないため、当時の形をそのまま組み立てる。
    def standard_paths
      blob = @attachment.blob
      filename = ERB::Util.url_encode(blob.filename.to_s)

      [
        "/rails/active_storage/blobs/redirect/#{blob.signed_id}/#{filename}",
        "/rails/active_storage/blobs/proxy/#{blob.signed_id}/#{filename}",
        "/rails/active_storage/blobs/#{blob.signed_id}/#{filename}",
        "/rails/active_storage/representations/redirect/#{blob.signed_id}/x/#{filename}",
        "/rails/active_storage/representations/proxy/#{blob.signed_id}/x/#{filename}",
        "/rails/active_storage/disk/#{ERB::Util.url_encode(blob.key)}/#{filename}"
      ]
    end
end
