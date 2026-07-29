require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "同じ部門へ二重に所属できない" do
    membership = Membership.new(user: users(:taro), department: departments(:sales))

    assert_not membership.valid?
  end

  test "別組織の部門へは所属できない" do
    membership = Membership.new(user: users(:outsider), department: departments(:sales))

    assert_not membership.valid?
  end

  test "主たる所属は利用者ごとに 1 件だけになる" do
    Membership.create!(user: users(:taro), department: departments(:development), primary: true)

    assert_equal 1, users(:taro).memberships.primary.count
    assert_equal departments(:development), users(:taro).reload.primary_department
  end
end
