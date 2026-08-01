require "test_helper"

# 部門の階層の組み立て。
#
# 上位を関連で 1 段ずつたどると、部門の件数と階層の深さの積だけ問い合わせが
# 出る。includes(:parent) は 1 段目しか先読みしないため、2 段目より上は
# そのまま問い合わせになる。
class DepartmentHierarchyTest < ActiveSupport::TestCase
  include QueryCountTestHelper

  # 部門の件数と階層の深さだけを変えて、同じ組み立てを 2 回数える。
  test "階層の組み立てで出る問い合わせが、部門の件数と深さで増えない" do
    shallow = build_hierarchy(code: "shallow", chains: 2, depth: 2)
    deep = build_hierarchy(code: "deep", chains: 8, depth: 5)

    shallow_count = count_queries { display_paths(shallow) }
    deep_count = count_queries { display_paths(deep) }

    assert_equal shallow_count, deep_count
  end

  test "まとめて読んでも階層の並びが変わらない" do
    departments = Department.with_ancestors(organizations(:main).departments.ordered)

    assert_equal "営業部 / 営業部 東日本課",
                 departments.find { |department| department.code == "sales-east" }.display_path
    assert_equal "開発部",
                 departments.find { |department| department.code == "development" }.display_path
  end

  test "上位を持たない部門は自身だけの並びになる" do
    assert_empty Department.with_ancestors([ departments(:sales) ]).first.ancestors
  end

  test "対象が空でも問い合わせを出さない" do
    assert_equal 0, count_queries { Department.with_ancestors(Department.none) }
  end

  test "別の組織の部門が混ざっていても、それぞれの階層を組み立てられる" do
    departments = Department.with_ancestors([ departments(:sales_east), departments(:other_general) ])

    assert_equal [ "営業部 / 営業部 東日本課", "総務部" ], departments.map(&:display_path)
  end

  # 検証で拒んでいるが、既存の記録が循環していた場合に終わらないことは避ける。
  test "上位が循環していても組み立てが終わる" do
    parent = departments(:sales)
    child = departments(:sales_east)
    Department.where(id: parent.id).update_all(parent_id: child.id)

    assert_equal [ child, parent ], Department.with_ancestors([ child.reload ]).first.ancestors
  end

  private
    def display_paths(organization)
      Department.with_ancestors(organization.departments.ordered).map(&:display_path)
    end

    # 深さ depth の連鎖を chains 本持つ組織を作る。
    def build_hierarchy(code:, chains:, depth:)
      organization = Organization.create!(name: "階層 #{code}", code: code)

      chains.times do |chain|
        parent = nil

        depth.times do |level|
          parent = organization.departments.create!(
            name: "部門 #{chain}-#{level}", code: "#{code}-#{chain}-#{level}", parent: parent
          )
        end
      end

      organization
    end
end
