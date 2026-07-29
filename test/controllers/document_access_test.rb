require "test_helper"

class DocumentAccessControlTest < ActionDispatch::IntegrationTest
  test "参照範囲外の文書は一覧に並ばない" do
    sign_in_as users(:hanako)

    get documents_url

    assert_select "a", text: documents(:travel_rule).title
    assert_select "a", text: documents(:sales_only_document).title, count: 0
  end

  test "参照範囲外の文書は直接参照できない" do
    sign_in_as users(:hanako)

    get document_url(documents(:sales_only_document))

    assert_response :not_found
  end

  test "参照範囲外の文書の添付は取得できない" do
    document = documents(:sales_only_document)
    document.attachments.attach(io: StringIO.new("a"), filename: "secret.txt", content_type: "text/plain")

    sign_in_as users(:hanako)

    get document_attachment_url(document, document.attachments.first)

    assert_response :not_found
  end

  test "参照できる文書の添付は取得できる" do
    document = documents(:travel_rule)
    document.attachments.attach(io: StringIO.new("a"), filename: "guide.txt", content_type: "text/plain")

    sign_in_as users(:hanako)

    get document_attachment_url(document, document.attachments.first)

    assert_response :success
    assert_equal "a", response.body
    assert_match "attachment", response.headers["Content-Disposition"]
  end

  test "ログインしていない場合は添付を取得できない" do
    document = documents(:travel_rule)
    document.attachments.attach(io: StringIO.new("a"), filename: "guide.txt", content_type: "text/plain")

    get document_attachment_url(document, document.attachments.first)

    assert_redirected_to new_session_path
  end

  test "組織全体へ公開する場合、指定した部門は取り除かれる" do
    sign_in_as users(:taro)

    post documents_url, params: {
      document: { title: "手引き", visibility: "organization", department_ids: [ departments(:sales).id ] }
    }

    assert_empty Document.last.departments
  end
end
