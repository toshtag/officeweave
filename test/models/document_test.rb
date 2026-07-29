require "test_helper"

class DocumentTest < ActiveSupport::TestCase
  test "件名があれば作成できる" do
    document = organizations(:main).documents.new(author: users(:hanako), title: "議事録")

    assert document.valid?
  end

  test "分類は付けなくてもよい" do
    assert_predicate documents(:uncategorized), :valid?
  end

  test "別組織の分類は付けられない" do
    document = documents(:travel_rule)
    document.document_category = document_categories(:other_org_category)

    assert_not document.valid?
  end

  test "分類で絞り込める" do
    scoped = organizations(:main).documents.in_category(document_categories(:rules).id)

    assert_includes scoped, documents(:travel_rule)
    assert_not_includes scoped, documents(:onboarding)
  end

  test "分類が空なら絞り込まない" do
    scoped = organizations(:main).documents.in_category(nil)

    assert_includes scoped, documents(:travel_rule)
    assert_includes scoped, documents(:onboarding)
  end

  test "作成者と管理者だけが変更できる" do
    assert documents(:onboarding).editable_by?(users(:hanako))
    assert documents(:onboarding).editable_by?(users(:taro))
    assert_not documents(:travel_rule).editable_by?(users(:hanako))
  end

  test "分類を削除しても文書は残る" do
    category = document_categories(:rules)

    assert_difference -> { Document.count }, 0 do
      category.destroy
    end

    assert_nil documents(:travel_rule).reload.document_category
  end
end
