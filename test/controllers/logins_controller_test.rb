require "test_helper"

# ログイン中の端末の一覧と終了。
#
# 資格情報が漏れた疑いに対して、利用者ができるのはパスワードの変更だけだった。
# 変更は他の端末のログインをすべて終わらせるが、どこから使われているのかは
# 見えない。見えないと、変更が必要かどうかを判断できない。
class LoginsControllerTest < ActionDispatch::IntegrationTest
  include PasswordlessProviderTestHelper

  test "自分のログインが一覧に出る" do
    other_device = users(:hanako).sessions.create!(user_agent: "別の端末", ip_address: "192.0.2.20")
    sign_in_as users(:hanako)

    get logins_url

    assert_response :success
    assert_select "[data-login-id='#{other_device.id}']"
    assert_includes response.body, "別の端末"
    assert_includes response.body, "192.0.2.20"
  end

  test "他の利用者のログインは出ない" do
    theirs = users(:taro).sessions.create!(user_agent: "他人の端末")
    sign_in_as users(:hanako)

    get logins_url

    assert_select "[data-login-id='#{theirs.id}']", count: 0
    refute_includes response.body, "他人の端末"
  end

  test "期限を過ぎたログインは出ない" do
    expired = users(:hanako).sessions.create!(user_agent: "古い端末")
    expired.update_columns(expires_at: 1.hour.ago, last_active_at: 1.hour.ago)
    sign_in_as users(:hanako)

    get logins_url

    # 認証には使えない記録である。並べると、終わらせる操作が必要に見える。
    assert_select "[data-login-id='#{expired.id}']", count: 0
  end

  test "今の端末が分かる" do
    sign_in_as users(:hanako)

    get logins_url

    assert_select "[data-login-current='true']", count: 1
  end

  test "1 件を終わらせられる" do
    other_device = users(:hanako).sessions.create!(user_agent: "別の端末")
    sign_in_as users(:hanako)

    delete login_url(other_device)

    assert_redirected_to logins_path
    assert_not Session.exists?(other_device.id)
  end

  test "他の利用者のログインは終わらせられない" do
    theirs = users(:taro).sessions.create!
    sign_in_as users(:hanako)

    delete login_url(theirs)

    assert_response :not_found
    assert Session.exists?(theirs.id)
  end

  test "今の端末以外をまとめて終わらせられる" do
    others = Array.new(2) { users(:hanako).sessions.create! }
    sign_in_as users(:hanako)

    delete logins_url

    assert_redirected_to logins_path
    # 残るのは操作した端末の 1 件だけとする。
    assert_equal 1, users(:hanako).sessions.count
    others.each { |session| assert_not Session.exists?(session.id) }
  end

  test "まとめて終わらせても、操作した端末では使い続けられる" do
    users(:hanako).sessions.create!
    sign_in_as users(:hanako)

    delete logins_url

    get root_url
    assert_response :success
  end

  test "終わらせたことを監査記録へ残す" do
    users(:hanako).sessions.create!
    users(:hanako).sessions.create!
    sign_in_as users(:hanako)

    assert_difference -> { AuditEvent.with_action("sessions_revoked").count }, 1 do
      delete logins_url
    end

    event = AuditEvent.with_action("sessions_revoked").recent_first.first

    assert_equal users(:hanako), event.actor
    # 何件を終わらせたのかが分からないと、後から範囲を確かめられない。
    assert_equal 2, event.details["count"]
  end

  test "1 件の終了も監査記録へ残す" do
    other_device = users(:hanako).sessions.create!
    sign_in_as users(:hanako)

    assert_difference -> { AuditEvent.with_action("sessions_revoked").count }, 1 do
      delete login_url(other_device)
    end

    assert_equal 1, AuditEvent.with_action("sessions_revoked").recent_first.first.details["count"]
  end

  test "終わらせるものが無ければ記録しない" do
    sign_in_as users(:hanako)

    assert_no_difference -> { AuditEvent.with_action("sessions_revoked").count } do
      delete logins_url
    end
  end

  test "ログインしていなければ見られない" do
    get logins_url

    assert_redirected_to new_session_path
  end

  test "設定から一覧へ行ける" do
    sign_in_as users(:hanako)

    get settings_url

    assert_select "a[href=?]", logins_path
  end

  test "外部の認証方式でも一覧を扱える" do
    # ログインの記録はこの製品が持つ。資格情報の置き場所とは別である。
    with_passwordless_provider do
      sign_in_as users(:hanako)

      get logins_url

      assert_response :success
    end
  end
end
