require "test_helper"

# パスワードの再設定。
#
# 今のパスワードを思い出せない利用者のための経路である。管理者を通さずに
# 資格情報を置き換えられるため、受け取れる相手をメールの宛先だけに限る。
#
# 利用者がいるかどうかを応答から読み取れないようにする。読み取れると、
# 組織に属するメールアドレスの一覧を、この経路から作れる。
class PasswordResetTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  NEW_PASSWORD = "a-reset-secret-value".freeze

  test "案内を本人へ送る" do
    assert_emails 1 do
      post password_resets_url, params: { email_address: users(:hanako).email_address }
    end

    assert_redirected_to new_session_path
    assert_equal [ users(:hanako).email_address ], ActionMailer::Base.deliveries.last.to
  end

  test "知らないメールアドレスでも同じ応答を返す" do
    assert_no_emails do
      post password_resets_url, params: { email_address: "nobody@example.com" }
    end

    assert_redirected_to new_session_path
    assert_equal I18n.t("password_resets.sent"), flash[:notice]
  end

  test "無効化された利用者へは送らない" do
    users(:hanako).deactivate!

    assert_no_emails do
      post password_resets_url, params: { email_address: users(:hanako).email_address }
    end

    assert_redirected_to new_session_path
    assert_equal I18n.t("password_resets.sent"), flash[:notice]
  end

  test "案内のリンクから新しいパスワードを設定できる" do
    patch password_reset_url(token_for(users(:hanako))), params: {
      user: { password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
    }

    assert_redirected_to new_session_path
    assert users(:hanako).reload.authenticate(NEW_PASSWORD)
  end

  test "期限を過ぎたリンクでは設定できない" do
    token = token_for(users(:hanako))

    travel User::PASSWORD_RESET_EXPIRES_IN + 1.minute do
      get edit_password_reset_url(token)
      assert_redirected_to new_password_reset_path

      patch password_reset_url(token), params: {
        user: { password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
      }
      assert_redirected_to new_password_reset_path
    end

    assert users(:hanako).reload.authenticate("password-for-tests")
  end

  test "一度使ったリンクは二度使えない" do
    token = token_for(users(:hanako))

    patch password_reset_url(token), params: {
      user: { password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
    }

    patch password_reset_url(token), params: {
      user: { password: "another-secret-value", password_confirmation: "another-secret-value" }
    }

    assert_redirected_to new_password_reset_path
    assert users(:hanako).reload.authenticate(NEW_PASSWORD)
  end

  test "組み立てた値では設定できない" do
    get edit_password_reset_url("not-a-real-token")

    assert_redirected_to new_password_reset_path
  end

  test "最低要件を満たさないパスワードは受け付けない" do
    patch password_reset_url(token_for(users(:hanako))), params: {
      user: { password: "short", password_confirmation: "short" }
    }

    assert_response :unprocessable_content
    assert users(:hanako).reload.authenticate("password-for-tests")
  end

  test "再設定すると、進行中のログインが終わる" do
    session = users(:hanako).sessions.create!

    patch password_reset_url(token_for(users(:hanako))), params: {
      user: { password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
    }

    assert_not Session.exists?(session.id)
  end

  test "再設定そのものではログインしない" do
    patch password_reset_url(token_for(users(:hanako))), params: {
      user: { password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
    }

    # 案内のメールを読める相手が、そのままログイン状態になることはしない。
    get root_url
    assert_redirected_to new_session_path
  end

  test "送信と再設定を監査記録へ残す" do
    assert_difference -> { AuditEvent.with_action("password_reset_requested").count }, 1 do
      post password_resets_url, params: { email_address: users(:hanako).email_address }
    end

    assert_difference -> { AuditEvent.with_action("password_reset_completed").count }, 1 do
      patch password_reset_url(token_for(users(:hanako))), params: {
        user: { password: NEW_PASSWORD, password_confirmation: NEW_PASSWORD }
      }
    end

    event = AuditEvent.with_action("password_reset_completed").recent_first.first

    # 操作したのは、ログインしていない相手である。対象だけが分かる。
    assert_nil event.actor
    assert_equal users(:hanako), event.target
  end

  test "知らないメールアドレスの要求は記録しない" do
    assert_no_difference -> { AuditEvent.count } do
      post password_resets_url, params: { email_address: "nobody@example.com" }
    end
  end

  test "ログイン画面から再設定へ行ける" do
    get new_session_url

    assert_select "a[href=?]", new_password_reset_path
  end

  test "パスワードを使わない認証方式では扱えない" do
    Authentication::ProviderRegistry.register(PasswordUpdateTest::PasswordlessProvider)
    ENV["AUTHENTICATION_PROVIDER"] = "passwordless"

    get new_password_reset_url
    assert_response :not_found

    assert_no_emails do
      post password_resets_url, params: { email_address: users(:hanako).email_address }
    end
    assert_response :not_found

    get new_session_url
    assert_select "a[href=?]", new_password_reset_path, count: 0
  ensure
    Authentication::ProviderRegistry.instance_variable_get(:@providers).delete("passwordless")
    ENV.delete("AUTHENTICATION_PROVIDER")
  end

  test "案内には再設定の経路と、心当たりがない場合の扱いを書く" do
    post password_resets_url, params: { email_address: users(:hanako).email_address }

    body = ActionMailer::Base.deliveries.last.body.to_s

    assert_includes body, "/password_resets/"
    # 送った覚えのない相手が受け取ることもある。何もしなくてよいことを伝える。
    assert_includes body, I18n.t("password_mailer.reset.ignore_hint", locale: users(:hanako).locale)
    # 期限は本文で伝える。開いたときに切れていると、理由が分からない。
    assert_includes body, I18n.t("password_mailer.reset.expires_hint",
                                 count: (User::PASSWORD_RESET_EXPIRES_IN / 60).to_i,
                                 locale: users(:hanako).locale)
  end

  private
    def token_for(user)
      user.password_reset_token
    end
end
