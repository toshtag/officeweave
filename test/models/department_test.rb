require "test_helper"

class DepartmentTest < ActiveSupport::TestCase
  test "名称と識別子があれば作成できる" do
    department = organizations(:main).departments.new(name: "総務部", code: "general")

    assert department.valid?
  end

  test "識別子は組織の中で重複できない" do
    department = organizations(:main).departments.new(name: "別の営業部", code: "sales")

    assert_not department.valid?
  end

  test "識別子は組織が違えば重複できる" do
    department = organizations(:other).departments.new(name: "営業部", code: "sales")

    assert department.valid?
  end

  test "識別子は前後の空白と大文字を正規化する" do
    department = organizations(:main).departments.create!(name: "総務部", code: "  General  ")

    assert_equal "general", department.code
  end

  test "別組織の部門を上位に指定できない" do
    department = departments(:development)
    department.parent = departments(:other_general)

    assert_not department.valid?
  end

  test "自身を上位に指定できない" do
    department = departments(:sales)
    department.parent = department

    assert_not department.valid?
  end

  test "循環する上位関係を作れない" do
    department = departments(:sales)
    department.parent = departments(:sales_east)

    assert_not department.valid?
  end

  test "上位からの並びを取り出せる" do
    assert_equal [ departments(:sales) ], departments(:sales_east).ancestors
    assert_equal "営業部 / 営業部 東日本課", departments(:sales_east).display_path
  end

  test "所属者がいても削除でき、所属も取り除かれる" do
    department = departments(:development)
    Membership.create!(user: users(:hanako), department: department)

    assert_difference -> { Membership.count }, -1 do
      department.destroy
    end
  end

  test "下位部門があると削除できない" do
    assert_not departments(:sales).destroy
    assert_predicate departments(:sales).errors[:base], :present?
  end
end
