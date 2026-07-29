require "test_helper"

class DocumentAttachmentTest < ActiveSupport::TestCase
  test "ファイルを添付できる" do
    document = documents(:travel_rule)
    document.attachments.attach(attachment_of(1.kilobyte))

    assert document.valid?
    assert_predicate document.attachments, :attached?
  end

  test "上限を超える大きさのファイルは添付できない" do
    document = documents(:travel_rule)
    document.attachments.attach(attachment_of(Document::MAX_ATTACHMENT_SIZE + 1))

    assert_not document.valid?
    assert_predicate document.errors[:attachments], :present?
  end

  test "上限を超える件数は添付できない" do
    document = documents(:travel_rule)
    (Document::MAX_ATTACHMENT_COUNT + 1).times { document.attachments.attach(attachment_of(1.kilobyte)) }

    assert_not document.valid?
  end

  test "文書を削除すると添付も取り除かれる" do
    document = documents(:travel_rule)
    document.attachments.attach(attachment_of(1.kilobyte))
    document.save!

    assert_difference -> { ActiveStorage::Attachment.count }, -1 do
      document.destroy
    end
  end

  private
    def attachment_of(size)
      {
        io: StringIO.new("a" * size),
        filename: "sample.txt",
        content_type: "text/plain"
      }
    end
end
