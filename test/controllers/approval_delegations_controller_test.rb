require "test_helper"

# 承認の委任の画面。
#
# 自分の委任だけを扱う。他人の委任を作れると、担当していない相手の権限を
# 誰かが横から広げられる。
class ApprovalDelegationsControllerTest < ActionDispatch::IntegrationTest
  test "自分の委任を作れる" do
    sign_in_as users(:approver)

    assert_difference -> { ApprovalDelegation.count }, 1 do
      post approval_delegations_url, params: {
        approval_delegation: { delegate_id: users(:outsider_free).id, starts_on: Date.current.to_s }
      }
    end

    delegation = ApprovalDelegation.recent_first.first

    assert_redirected_to approval_delegations_path
    assert_equal users(:approver), delegation.delegator
    assert_equal users(:outsider_free), delegation.delegate
  end

  test "委任した相手は選べる利用者から作る" do
    sign_in_as users(:approver)

    get approval_delegations_url

    assert_response :success
    # 自分自身は選べない。委任にならない。
    assert_select "select[name='approval_delegation[delegate_id]'] option[value=?]",
                  users(:approver).id.to_s, count: 0
  end

  test "自分の委任だけが一覧に出る" do
    mine = ApprovalDelegation.create!(organization: organizations(:main), delegator: users(:approver),
                                     delegate: users(:outsider_free), starts_on: Date.current)
    theirs = ApprovalDelegation.create!(organization: organizations(:main), delegator: users(:taro),
                                       delegate: users(:hanako), starts_on: Date.current)
    sign_in_as users(:approver)

    get approval_delegations_url

    assert_select "[data-delegation-id='#{mine.id}']"
    assert_select "[data-delegation-id='#{theirs.id}']", count: 0
  end

  test "自分の委任を終わらせられる" do
    delegation = ApprovalDelegation.create!(organization: organizations(:main), delegator: users(:approver),
                                           delegate: users(:outsider_free), starts_on: Date.current)
    sign_in_as users(:approver)

    assert_difference -> { ApprovalDelegation.count }, -1 do
      delete approval_delegation_url(delegation)
    end

    assert_redirected_to approval_delegations_path
  end

  test "他人の委任は終わらせられない" do
    delegation = ApprovalDelegation.create!(organization: organizations(:main), delegator: users(:taro),
                                           delegate: users(:hanako), starts_on: Date.current)
    sign_in_as users(:approver)

    assert_no_difference -> { ApprovalDelegation.count } do
      delete approval_delegation_url(delegation)
    end

    assert_response :not_found
  end

  test "誤った委任は理由を示す" do
    sign_in_as users(:approver)

    assert_no_difference -> { ApprovalDelegation.count } do
      post approval_delegations_url, params: {
        approval_delegation: { delegate_id: users(:approver).id, starts_on: Date.current.to_s }
      }
    end

    assert_response :unprocessable_content
  end

  test "ログインしていなければ扱えない" do
    get approval_delegations_url

    assert_redirected_to new_session_path
  end

  test "設定から一覧へ行ける" do
    sign_in_as users(:approver)

    get settings_url

    assert_select "a[href=?]", approval_delegations_path
  end

  test "委任を作ったことを監査記録へ残す" do
    sign_in_as users(:approver)

    assert_difference -> { AuditEvent.with_action("approval_delegation_created").count }, 1 do
      post approval_delegations_url, params: {
        approval_delegation: { delegate_id: users(:outsider_free).id, starts_on: Date.current.to_s }
      }
    end
  end

  test "委任を終わらせたことも監査記録へ残す" do
    delegation = ApprovalDelegation.create!(organization: organizations(:main), delegator: users(:approver),
                                           delegate: users(:outsider_free), starts_on: Date.current)
    sign_in_as users(:approver)

    assert_difference -> { AuditEvent.with_action("approval_delegation_deleted").count }, 1 do
      delete approval_delegation_url(delegation)
    end
  end
end
