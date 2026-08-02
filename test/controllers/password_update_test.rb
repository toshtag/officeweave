require "test_helper"

# 自分のパスワードの変更。
#
# 管理者による変更（利用者の管理）とは別の経路とする。自分の変更では、
# 今のパスワードを知っていることを求める。求めないと、開いたままの画面を
# 使える相手が、資格情報を置き換えて利用者を締め出せる。
class PasswordUpdateTest < ActionDispatch::IntegrationTest
  include PasswordlessProviderTestHelper

  NEW_PASSWORD = "a-brand-new-secret-value".freeze

  test "今のパスワードを添えて変更できる" do
    sign_in_as users(:hanako)

    patch password_url, params: {
      current_password: "password-for-tests",
      user: { password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
    }

    assert_redirected_to settings_path
    assert users(:hanako).reload.authenticate(NEW_PASSWORD)
  end

  test "今のパスワードが違えば変更しない" do
    sign_in_as users(:hanako)

    patch password_url, params: {
      current_password: "wrong-password",
      user: { password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
    }

    assert_response :unprocessable_content
    assert users(:hanako).reload.authenticate("password-for-tests")
  end

  test "今のパスワードを添えなければ変更しない" do
    sign_in_as users(:hanako)

    patch password_url, params: {
      user: { password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
    }

    assert_response :unprocessable_content
    assert users(:hanako).reload.authenticate("password-for-tests")
  end

  test "確認が一致しなければ変更しない" do
    sign_in_as users(:hanako)

    patch password_url, params: {
      current_password: "password-for-tests",
      user: { password: NEW_PASSWORD, password_confirmation: "#{NEW_PASSWORD}-different" }
    }

    assert_response :unprocessable_content
    assert users(:hanako).reload.authenticate("password-for-tests")
  end

  test "最低要件を満たさないパスワードへは変更しない" do
    sign_in_as users(:hanako)

    patch password_url, params: {
      current_password: "password-for-tests",
      user: { password: "short", password_confirmation: "short" }
    }

    assert_response :unprocessable_content
    assert users(:hanako).reload.authenticate("password-for-tests")
  end

  test "変更すると、他の端末のログインが終わる" do
    other = users(:hanako).sessions.create!
    sign_in_as users(:hanako)

    patch password_url, params: {
      current_password: "password-for-tests",
      user: { password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
    }

    assert_not Session.exists?(other.id)
  end

  test "変更しても、操作した端末ではログインが続く" do
    sign_in_as users(:hanako)

    patch password_url, params: {
      current_password: "password-for-tests",
      user: { password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
    }

    # 変更のたびにログイン画面へ戻す形にすると、変更をためらう理由になる。
    get root_url
    assert_response :success
  end

  test "変更を監査記録へ残す" do
    sign_in_as users(:hanako)

    assert_difference -> { AuditEvent.with_action("password_changed").count }, 1 do
      patch password_url, params: {
        current_password: "password-for-tests",
        user: { password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
      }
    end

    event = AuditEvent.with_action("password_changed").recent_first.first

    assert_equal users(:hanako), event.actor
    assert_equal users(:hanako), event.target
  end

  test "失敗した変更は監査記録へ残さない" do
    sign_in_as users(:hanako)

    assert_no_difference -> { AuditEvent.with_action("password_changed").count } do
      patch password_url, params: {
        current_password: "wrong-password",
        user: { password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
      }
    end
  end

  test "ログインしていなければ変更できない" do
    patch password_url, params: {
      current_password: "password-for-tests",
      user: { password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
    }

    assert_redirected_to new_session_path
    assert users(:hanako).reload.authenticate("password-for-tests")
  end

  test "変更の画面へは設定から行ける" do
    sign_in_as users(:hanako)

    get settings_url

    assert_select "a[href=?]", edit_password_path
  end

  test "パスワードを使わない認証方式では扱えない" do
    with_passwordless_provider do
      sign_in_as users(:hanako)

      get edit_password_url
      assert_response :not_found

      patch password_url, params: {
        current_password: "password-for-tests",
        user: { password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
      }
      assert_response :not_found
      assert users(:hanako).reload.authenticate("password-for-tests")
    end
  end

  test "パスワードを使わない認証方式では、設定から案内しない" do
    with_passwordless_provider do
      sign_in_as users(:hanako)

      get settings_url

      assert_select "a[href=?]", edit_password_path, count: 0
    end
  end
end
