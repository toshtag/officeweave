require "test_helper"

# データベースだけが保てる不変条件の、同時の書き込みに対する確認。
#
# 模型の確認は、確かめてから書き込むまでの間に相手も確かめ終える状況を
# 防げない。それを確かめるには別々の接続から実行する必要があるため、
# このクラスだけトランザクションで囲む既定を外す。
class DatabaseInvariantConcurrencyTest < ActiveSupport::TestCase
  include IsolatedOrganizationTestHelper

  self.use_transactional_tests = false

  ORGANIZATION_CODE = "database-invariants".freeze

  # 待機には上限を持たせる。退行を CI の停止ではなく失敗として受け取る。
  COMPLETION_TIMEOUT = 30

  setup do
    @organization = create_isolated_organization(name: "不変条件の同時実行の確認", code: ORGANIZATION_CODE)
    @delegator = create_user("delegator@example.com")
    @delegate = create_user("delegate@example.com")
  end

  teardown do
    discard_organization(@organization)
  end

  test "期間の重なる委任を同時に作っても、成立するのは片方だけ" do
    outcomes = in_parallel(2) do
      delegation = build_delegation
      valid = delegation.valid?
      # 相手も確認を終えるまで待つ。順に進めると競合そのものが起きない。
      wait_for_others
      valid && delegation.save_with_overlap_check
    end

    assert_equal 1, outcomes.count(true), "成立したのは #{outcomes.count(true)} 件（#{outcomes.inspect}）"
    assert_equal 1, ApprovalDelegation.where(delegator_id: @delegator.id, delegate_id: @delegate.id).count
  end

  # 同時に届いた 2 つの書き込みは、待ち合いになり得る。中断された側は、
  # 相手が確定した状態でもう一度試して、制約に触れたという答えを受け取る。
  # 例外がそのまま画面へ届いてはならない。
  test "重なりで失われるのは記録だけで、例外は画面へ届かない" do
    rejected = nil

    in_parallel(2) do
      delegation = build_delegation
      valid = delegation.valid?
      wait_for_others
      rejected = delegation unless valid && delegation.save_with_overlap_check
      true
    end

    assert_includes rejected.errors.attribute_names, :starts_on
  end

  test "互いを親にする更新を同時に行っても、循環は残らない" do
    first = create_department("cycle-a")
    second = create_department("cycle-b")

    in_parallel(2) do |index|
      target, parent = index.zero? ? [ first, second ] : [ second, first ]
      record = Department.find(target.id)
      record.parent_id = parent.id
      valid = record.valid?
      wait_for_others
      # 待ち合いになった場合の再試行は模型が持つ。ここでは受け取らない。
      valid && record.save_with_cycle_check
    end

    assert_no_cycles
  end

  test "自分を親にする更新は、直接の書き込みでも拒む" do
    department = create_department("self-parent")

    error = assert_raises(ActiveRecord::StatementInvalid) do
      Department.where(id: department.id).update_all(parent_id: department.id)
    end

    assert DatabaseConstraint.check_violation?(error, constraint: Department::CYCLE_CONSTRAINT)
  end

  test "循環する階層は、模型を通さない書き込みでも拒む" do
    parent = create_department("outer")
    child = create_department("inner", parent: parent)

    error = assert_raises(ActiveRecord::StatementInvalid) do
      Department.where(id: parent.id).update_all(parent_id: child.id)
    end

    assert DatabaseConstraint.check_violation?(error, constraint: Department::CYCLE_CONSTRAINT)
    assert_no_cycles
  end

  test "重ならない委任は、模型を通さない書き込みでも通る" do
    build_delegation(starts_on: Date.new(2026, 9, 1), ends_on: Date.new(2026, 9, 30)).save!

    assert_nothing_raised do
      build_delegation(starts_on: Date.new(2026, 10, 1), ends_on: Date.new(2026, 10, 31)).save(validate: false)
    end
  end

  test "終わりの日が接する委任は重ならない扱いにする" do
    build_delegation(starts_on: Date.new(2026, 9, 1), ends_on: Date.new(2026, 9, 30)).save!

    # 終わりの日を含む期間として扱う。翌日から始まる委任は重ならない。
    assert_nothing_raised do
      build_delegation(starts_on: Date.new(2026, 10, 1), ends_on: nil).save(validate: false)
    end
  end

  test "終わりの日が同じ委任は重なりとして拒む" do
    build_delegation(starts_on: Date.new(2026, 9, 1), ends_on: Date.new(2026, 9, 30)).save!

    error = assert_raises(ActiveRecord::StatementInvalid) do
      build_delegation(starts_on: Date.new(2026, 9, 30), ends_on: Date.new(2026, 10, 5)).save(validate: false)
    end

    assert DatabaseConstraint.exclusion_violation?(error, constraint: ApprovalDelegation::OVERLAP_CONSTRAINT)
  end

  test "相手が違えば期間が重なってよい" do
    other = create_user("another-delegate@example.com")
    build_delegation(starts_on: Date.new(2026, 9, 1), ends_on: Date.new(2026, 9, 30)).save!

    assert_nothing_raised do
      build_delegation(delegate: other, starts_on: Date.new(2026, 9, 1),
                       ends_on: Date.new(2026, 9, 30)).save(validate: false)
    end
  end

  private
    def build_delegation(delegate: nil, starts_on: Date.new(2026, 9, 1), ends_on: Date.new(2026, 9, 30))
      ApprovalDelegation.new(organization: @organization, delegator: @delegator,
                             delegate: delegate || @delegate, starts_on: starts_on, ends_on: ends_on)
    end

    def create_user(email)
      @organization.users.create!(name: email, email_address: email, password: "a-long-enough-password")
    end

    def create_department(code, parent: nil)
      @organization.departments.create!(name: code, code: code, parent: parent)
    end

    # 上へたどって自分に戻る部門が無いことを確かめる。
    def assert_no_cycles
      @organization.departments.reload.each do |department|
        assert_not_includes department.ancestors.map(&:id), department.id, "#{department.code} が循環している"
      end
    end

    def in_parallel(count, &block)
      @barrier = Concurrent::CyclicBarrier.new(count)
      outcomes = Array.new(count)

      threads = count.times.map do |index|
        Thread.new do
          outcomes[index] = ActiveRecord::Base.connection_pool.with_connection { block.call(index) }
        end
      end

      threads.each { |thread| assert thread.join(COMPLETION_TIMEOUT), "接続が時間内に終わらなかった" }
      outcomes
    end

    def wait_for_others
      @barrier.wait
    end
end
