require "test_helper"

# 代理承認。
#
# 承認を担当する利用者が不在のあいだ、別の利用者が代わりに決裁できるようにする。
# 担当そのものは移さない。移すと、戻し忘れたときに誰が担当なのか分からなくなる。
#
# 誰の代わりに決裁したかは記録へ残す。残さないと、経路を通した相手と
# 実際に判断した相手が食い違ったまま追えなくなる。
class ApprovalDelegationTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:main)
    @approver = users(:approver)
    @delegate = users(:outsider_free)
  end

  test "期間の内側では有効になる" do
    delegation = create_delegation(starts_on: Date.current, ends_on: Date.current)

    assert_predicate delegation, :active?
    assert_includes ApprovalDelegation.active, delegation
  end

  test "終わりを決めない委任は続く" do
    delegation = create_delegation(starts_on: Date.current, ends_on: nil)

    assert_predicate delegation, :active?
  end

  test "始まる前と終わったあとは無効になる" do
    future = create_delegation(starts_on: Date.current + 1, ends_on: nil)
    past = create_delegation(starts_on: Date.current - 10, ends_on: Date.current - 1,
                             delegate: users(:hanako))

    refute_predicate future, :active?
    refute_predicate past, :active?
    assert_empty ApprovalDelegation.active.where(id: [ future.id, past.id ])
  end

  test "自分自身へは委任できない" do
    delegation = build_delegation(delegate: @approver)

    assert_not delegation.valid?
    assert_includes delegation.errors.attribute_names, :delegate
  end

  test "終わりが始まりより前の委任は作れない" do
    delegation = build_delegation(starts_on: Date.current, ends_on: Date.current - 1)

    assert_not delegation.valid?
    assert_includes delegation.errors.attribute_names, :ends_on
  end

  test "組織をまたぐ委任は作れない" do
    delegation = build_delegation(delegate: users(:outsider))

    assert_not delegation.valid?
  end

  test "無効化された利用者へは委任できない" do
    @delegate.deactivate!

    assert_not build_delegation.valid?
  end

  test "同じ相手への重ならない委任は作れる" do
    create_delegation(starts_on: Date.current - 10, ends_on: Date.current - 5)

    assert build_delegation(starts_on: Date.current, ends_on: Date.current + 5).valid?
  end

  test "同じ相手への重なる委任は作れない" do
    # 同じ期間に同じ委任が 2 件あっても、できることは変わらない。
    create_delegation(starts_on: Date.current - 1, ends_on: Date.current + 5)

    assert_not build_delegation(starts_on: Date.current, ends_on: nil).valid?
  end

  private
    def build_delegation(delegator: @approver, delegate: @delegate,
                         starts_on: Date.current, ends_on: nil)
      @organization.approval_delegations.new(delegator: delegator, delegate: delegate,
                                             starts_on: starts_on, ends_on: ends_on)
    end

    def create_delegation(**attributes)
      build_delegation(**attributes).tap(&:save!)
    end
end
