require "test_helper"

class DocumentAccessTest < ActiveSupport::TestCase
  test "組織全体の文書は誰にでも見える" do
    assert_includes Document.visible_to(users(:hanako)), documents(:travel_rule)
  end

  test "部門を指定した文書は、その部門の所属者だけに見える" do
    assert_includes Document.visible_to(users(:taro)), documents(:sales_only_document)
    assert_not_includes Document.visible_to(users(:hanako)), documents(:sales_only_document)
  end

  test "作成者は参照範囲に関わらず自分の文書を見られる" do
    document = organizations(:main).documents.create!(
      author: users(:hanako), title: "花子の手引き", visibility: "departments",
      departments: [ departments(:sales) ]
    )

    assert_includes Document.visible_to(users(:hanako)), document
  end

  test "別組織の文書は見えない" do
    assert_not_includes Document.visible_to(users(:taro)), documents(:other_org_document)
  end

  test "部門を指定した場合、参照先が空では保存できない" do
    document = organizations(:main).documents.new(
      author: users(:taro), title: "手引き", visibility: "departments"
    )

    assert_not document.valid?
  end

  test "別組織の部門は参照先に指定できない" do
    document = organizations(:main).documents.new(
      author: users(:taro), title: "手引き", visibility: "departments",
      departments: [ departments(:other_general) ]
    )

    assert_not document.valid?
  end
end
