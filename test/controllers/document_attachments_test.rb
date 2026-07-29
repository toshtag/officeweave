require "test_helper"

class DocumentAttachmentsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:taro) }

  test "添付ファイルを付けて作成できる" do
    assert_difference -> { ActiveStorage::Attachment.count }, 1 do
      post documents_url, params: {
        document: { title: "手順書", attachments: [ uploaded_file ] }
      }
    end

    assert_predicate Document.last.attachments, :attached?
  end

  test "添付ファイルを取り除ける" do
    document = documents(:travel_rule)
    document.attachments.attach(io: StringIO.new("a"), filename: "old.txt", content_type: "text/plain")
    attachment = document.attachments.first

    assert_difference -> { ActiveStorage::Attachment.count }, -1 do
      patch document_url(document), params: {
        document: { title: document.title, remove_attachment_ids: [ attachment.id ] }
      }
    end
  end

  test "添付ファイルの一覧が文書の画面に並ぶ" do
    document = documents(:travel_rule)
    document.attachments.attach(io: StringIO.new("a"), filename: "guide.txt", content_type: "text/plain")

    get document_url(document)

    assert_select "#document-attachments"
    assert_select "a", text: "guide.txt"
  end

  test "上限を超えるファイルは受け付けず、理由が示される" do
    assert_no_difference -> { Document.count } do
      post documents_url, params: {
        document: { title: "手順書", attachments: [ uploaded_file(Document::MAX_ATTACHMENT_SIZE + 1) ] }
      }
    end

    assert_response :unprocessable_content
    assert_select ".error-summary"
  end

  private
    def uploaded_file(size = 1.kilobyte)
      Rack::Test::UploadedFile.new(StringIO.new("a" * size), "text/plain", original_filename: "sample.txt")
    end
end
