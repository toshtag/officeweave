require "test_helper"

class DocumentSearchControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:taro) }

  test "語句で絞り込める" do
    get documents_url(query: "旅費")

    assert_response :success
    assert_select "a", text: documents(:travel_rule).title
    assert_select "a", text: documents(:onboarding).title, count: 0
  end

  test "件数が示される" do
    get documents_url(query: "旅費")

    assert_select "[role=status]", text: /1/
  end

  test "一致しない場合も画面が表示される" do
    get documents_url(query: "存在しない語句")

    assert_response :success
    assert_select "[role=status]"
  end

  test "語句と分類を同時に指定できる" do
    get documents_url(query: "手続き", document_category_id: document_categories(:rules).id)

    assert_select "a", text: documents(:onboarding).title, count: 0
  end

  test "参照範囲の外は検索でも出てこない" do
    sign_out
    sign_in_as users(:hanako)

    get documents_url(query: "手引き")

    assert_select "a", text: documents(:sales_only_document).title, count: 0
  end
end
