require "test_helper"

class DocumentSearchTest < ActiveSupport::TestCase
  test "日本語の語句で件名を探せる" do
    results = organizations(:main).documents.search("旅費")

    assert_includes results, documents(:travel_rule)
    assert_not_includes results, documents(:onboarding)
  end

  test "日本語の語句で本文を探せる" do
    results = organizations(:main).documents.search("入社日")

    assert_includes results, documents(:onboarding)
  end

  test "語の区切りがない文の途中でも探せる" do
    results = organizations(:main).documents.search("旅費の取り扱い")

    assert_includes results, documents(:travel_rule)
  end

  test "英語の語句で探せる" do
    document = organizations(:main).documents.create!(
      author: users(:taro), title: "Remote work guideline", body: "How to work from home."
    )

    assert_includes organizations(:main).documents.search("guideline"), document
    assert_includes organizations(:main).documents.search("work from home"), document
  end

  test "大文字と小文字の違いを無視する" do
    document = organizations(:main).documents.create!(author: users(:taro), title: "Remote Work")

    assert_includes organizations(:main).documents.search("remote work"), document
  end

  test "空の語句では絞り込まない" do
    assert_equal organizations(:main).documents.count, organizations(:main).documents.search("").count
    assert_equal organizations(:main).documents.count, organizations(:main).documents.search(nil).count
  end

  test "部分一致の記号は文字として扱う" do
    document = organizations(:main).documents.create!(author: users(:taro), title: "100% の達成率")

    assert_includes organizations(:main).documents.search("100%"), document
    assert_not_includes organizations(:main).documents.search("%"), documents(:travel_rule)
  end

  test "参照範囲と組み合わせて絞り込める" do
    results = Document.visible_to(users(:hanako)).search("手引き")

    assert_not_includes results, documents(:sales_only_document)
  end
end
