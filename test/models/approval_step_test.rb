require "test_helper"

# 承認の段。
#
# 種別ごとに、承認を担当する部門を並べる。1 段だけの種別は、これまでと
# 同じ振る舞いになる。進行中の申請の意味を変えないため、既にあった
# 「承認部門」は 1 段目として移す。
class ApprovalStepTest < ActiveSupport::TestCase
  setup do
    @request_type = request_types(:leave)
  end

  test "承認部門は 1 段目として持つ" do
    # 単段の種別は、これまでと同じ担当になる。
    assert_equal 1, @request_type.approval_steps.count
    assert_equal departments(:sales), @request_type.approval_steps.first.approver_department
  end

  test "段は並びの順に読む" do
    @request_type.approval_steps.create!(position: 30, approver_department: departments(:sales))
    @request_type.approval_steps.create!(position: 20, approver_department: departments(:sales_east))

    assert_equal [ 10, 20, 30 ], @request_type.approval_steps.reload.ordered.map(&:position)
  end

  test "同じ並びの段を 2 つ持てない" do
    # どちらが先の段かを決められない。
    duplicate = @request_type.approval_steps.new(position: @request_type.approval_steps.first.position)

    assert_not duplicate.valid?
    assert_includes duplicate.errors.attribute_names, :position
  end

  test "部門を指定しない段は管理者が担当する" do
    step = @request_type.approval_steps.create!(position: 20, approver_department: nil)

    assert step.approvable_by?(users(:taro))
    refute step.approvable_by?(users(:hanako))
  end

  test "部門を指定した段は、その部門の利用者が担当する" do
    step = @request_type.approval_steps.first

    assert step.approvable_by?(users(:approver))
    refute step.approvable_by?(users(:outsider_free))
    # 管理者はすべての段を担当する。
    assert step.approvable_by?(users(:taro))
  end

  test "他の組織の部門は指定できない" do
    step = @request_type.approval_steps.new(position: 20,
                                           approver_department: organizations(:other).departments.first)

    assert_not step.valid?
  end

  test "段を指定せずに作った種別は、管理者が担当する段を 1 つ持つ" do
    # 1 段も無い種別は、提出しても誰も担当しない。
    # 指定が無い場合の担当は、これまでの「承認部門なし」と同じ管理者とする。
    type = current_organization.request_types.create!(name: "段なし", code: "no-steps")

    assert_equal 1, type.approval_steps.count
    assert_nil type.approval_steps.first.approver_department
  end

  test "最後の段だけは消せない" do
    step = @request_type.approval_steps.first

    assert_not step.destroy
    assert @request_type.approval_steps.reload.exists?(step.id)
  end

  test "段が 2 つあれば消せる" do
    added = @request_type.approval_steps.create!(position: 20, approver_department: departments(:sales))

    assert added.destroy
    assert_equal 1, @request_type.approval_steps.reload.count
  end

  private
    def current_organization = organizations(:main)
end
