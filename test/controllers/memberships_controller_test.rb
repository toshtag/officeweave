require "test_helper"

class MembershipsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:taro) }

  test "所属を追加できる" do
    assert_difference -> { Membership.count }, 1 do
      post department_memberships_url(departments(:development)),
           params: { membership: { user_id: users(:hanako).id } }
    end

    assert_redirected_to departments(:development)
  end

  test "別組織の利用者は所属させられない" do
    assert_no_difference -> { Membership.count } do
      post department_memberships_url(departments(:development)),
           params: { membership: { user_id: users(:outsider).id } }
    end
  end

  test "所属を解除できる" do
    assert_difference -> { Membership.count }, -1 do
      delete department_membership_url(departments(:sales), memberships(:taro_sales))
    end

    assert_redirected_to departments(:sales)
  end

  test "別組織の部門へは所属を追加できない" do
    post department_memberships_url(departments(:other_general)),
         params: { membership: { user_id: users(:taro).id } }

    assert_response :not_found
  end
end
