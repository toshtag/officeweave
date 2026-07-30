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

  test "添付ファイルを追加しても既存の添付ファイルが残る" do
    document = documents(:travel_rule)
    attach_text(document, "keep_a.txt")
    attach_text(document, "keep_b.txt")

    patch document_url(document), params: {
      document: { title: document.title, attachments: [ uploaded_file(filename: "added.txt") ] }
    }

    assert_redirected_to document_url(document)
    assert_equal %w[added.txt keep_a.txt keep_b.txt], attachment_filenames(document)
  end

  test "文書の更新に失敗した場合は選択した添付ファイルが削除されない" do
    document = documents(:travel_rule)
    keep_a = attach_text(document, "keep_a.txt")
    attach_text(document, "keep_b.txt")

    patch document_url(document), params: {
      document: { title: "", remove_attachment_ids: [ keep_a.id ] }
    }

    assert_response :unprocessable_content
    assert_equal %w[keep_a.txt keep_b.txt], attachment_filenames(document)
    assert ActiveStorage::Blob.exists?(keep_a.blob_id), "取り除かなかった添付の Blob が残ること"
    assert keep_a.blob.service.exist?(keep_a.blob.key), "取り除かなかった添付の保存実体が残ること"
  end

  test "添付ファイルの追加と選択削除を同時に行える" do
    document = documents(:travel_rule)
    removed = attach_text(document, "remove.txt")
    attach_text(document, "keep.txt")

    patch document_url(document), params: {
      document: { title: document.title,
                  remove_attachment_ids: [ removed.id ],
                  attachments: [ uploaded_file(filename: "added.txt") ] }
    }

    assert_redirected_to document_url(document)
    assert_equal %w[added.txt keep.txt], attachment_filenames(document)
  end

  test "文書の更新に失敗した場合は追加した添付ファイルが反映されない" do
    document = documents(:travel_rule)
    attach_text(document, "keep.txt")

    patch document_url(document), params: {
      document: { title: "", attachments: [ uploaded_file(filename: "added.txt") ] }
    }

    assert_response :unprocessable_content
    assert_equal %w[keep.txt], attachment_filenames(document)
  end

  test "上限件数の文書へ追加すると受け付けず、既存の添付ファイルが残る" do
    document = documents(:travel_rule)
    filenames = (1..Document::MAX_ATTACHMENT_COUNT).map { |number| format("file_%02d.txt", number) }
    filenames.each { |filename| attach_text(document, filename) }

    patch document_url(document), params: {
      document: { title: document.title, attachments: [ uploaded_file(filename: "added.txt") ] }
    }

    assert_response :unprocessable_content
    assert_equal filenames, attachment_filenames(document)
  end

  test "上限件数の文書でも削除と追加を同時に行えば保存できる" do
    document = documents(:travel_rule)
    filenames = (1..Document::MAX_ATTACHMENT_COUNT).map { |number| format("file_%02d.txt", number) }
    removed = attach_text(document, filenames.first)
    filenames.drop(1).each { |filename| attach_text(document, filename) }

    patch document_url(document), params: {
      document: { title: document.title,
                  remove_attachment_ids: [ removed.id ],
                  attachments: [ uploaded_file(filename: "added.txt") ] }
    }

    assert_redirected_to document_url(document)
    assert_equal (filenames.drop(1) + %w[added.txt]).sort, attachment_filenames(document)
  end

  test "他の文書の添付ファイルを削除対象に指定しても削除されない" do
    document = documents(:travel_rule)
    other_document = documents(:onboarding)
    other_attachment = attach_text(other_document, "other.txt")

    patch document_url(document), params: {
      document: { title: document.title, remove_attachment_ids: [ other_attachment.id ] }
    }

    assert_redirected_to document_url(document)
    assert_equal %w[other.txt], attachment_filenames(other_document)
  end

  private
    def uploaded_file(size = 1.kilobyte, filename: "sample.txt")
      Rack::Test::UploadedFile.new(StringIO.new("a" * size), "text/plain", original_filename: filename)
    end

    def attach_text(document, filename)
      document.attachments.attach(io: StringIO.new("a"), filename: filename, content_type: "text/plain")
      document.reload.attachments.find { |attachment| attachment.filename.to_s == filename }
    end

    def attachment_filenames(document)
      document.reload.attachments.map { |attachment| attachment.filename.to_s }.sort
    end
end
