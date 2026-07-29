require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  test "自組織の文書だけが並ぶ" do
    sign_in_as users(:hanako)

    get documents_url

    assert_response :success
    assert_select "a", text: documents(:travel_rule).title
    assert_select "a", text: documents(:other_org_document).title, count: 0
  end

  test "分類で絞り込める" do
    sign_in_as users(:hanako)

    get documents_url(document_category_id: document_categories(:rules).id)

    assert_select "a", text: documents(:travel_rule).title
    assert_select "a", text: documents(:onboarding).title, count: 0
  end

  test "別組織の文書は参照できない" do
    sign_in_as users(:taro)

    get document_url(documents(:other_org_document))

    assert_response :not_found
  end

  test "文書を作成できる" do
    sign_in_as users(:hanako)

    assert_difference -> { Document.count }, 1 do
      post documents_url, params: { document: { title: "議事録", body: "内容" } }
    end

    assert_equal users(:hanako), Document.last.author
  end

  test "作成者でない一般利用者は編集できない" do
    sign_in_as users(:hanako)

    get edit_document_url(documents(:travel_rule))

    assert_response :forbidden
  end

  test "管理者は他人の文書も編集できる" do
    sign_in_as users(:taro)

    patch document_url(documents(:onboarding)), params: { document: { title: "入社案内" } }

    assert_equal "入社案内", documents(:onboarding).reload.title
  end

  test "一般利用者は分類を管理できない" do
    sign_in_as users(:hanako)

    get document_categories_url

    assert_response :forbidden
  end
end
