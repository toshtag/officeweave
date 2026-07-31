require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:taro) }

  test "自組織の利用者だけが一覧に並ぶ" do
    get users_url

    assert_response :success
    assert_select "td", text: users(:hanako).email_address
    assert_select "td", text: users(:outsider).email_address, count: 0
  end

  test "利用者を追加できる" do
    assert_difference -> { User.count }, 1 do
      post users_url, params: {
        user: { name: "鈴木 一郎", email_address: "ichiro@example.com",
                password: "a-long-secret-value", password_confirmation: "a-long-secret-value",
                role: "member" }
      }
    end

    assert_redirected_to users_path
    assert_equal organizations(:main), User.find_by(email_address: "ichiro@example.com").organization
  end

  test "パスワードの確認が一致しないと追加できない" do
    assert_no_difference -> { User.count } do
      post users_url, params: {
        user: { name: "鈴木 一郎", email_address: "ichiro@example.com",
                password: "a-long-secret-value", password_confirmation: "a-different-value" }
      }
    end

    assert_response :unprocessable_content
  end

  test "15 文字に満たないパスワードでは追加できない" do
    assert_no_difference [ -> { User.count }, -> { AuditEvent.count } ] do
      post users_url, params: {
        user: { name: "鈴木 一郎", email_address: "ichiro@example.com",
                password: "abcdefghijklmn", password_confirmation: "abcdefghijklmn" }
      }
    end

    assert_response :unprocessable_content
  end

  test "既知の初期値では追加できない" do
    assert_no_difference [ -> { User.count }, -> { AuditEvent.count } ] do
      post users_url, params: {
        user: { name: "鈴木 一郎", email_address: "ichiro@example.com",
                password: "change_me", password_confirmation: "change_me" }
      }
    end

    assert_response :unprocessable_content
    assert_select ".error-summary", text: /#{Regexp.escape(known_unsafe_message)}/
  end

  test "英語の画面でも拒む理由が示される" do
    users(:taro).update!(locale: "en")

    post users_url, params: {
      user: { name: "Ichiro Suzuki", email_address: "ichiro@example.com",
              password: "change_me", password_confirmation: "change_me" }
    }

    assert_response :unprocessable_content
    assert_select ".error-summary", text: /#{Regexp.escape(known_unsafe_message(:en))}/
  end

  # 入力欄の minlength と required は通ってしまう値。要求を直接送って確かめる。
  test "空白だけのパスワードでは追加できない" do
    assert_no_difference [ -> { User.count }, -> { AuditEvent.count } ] do
      post users_url, params: {
        user: { name: "鈴木 一郎", email_address: "ichiro@example.com",
                password: " " * 15, password_confirmation: " " * 15 }
      }
    end

    assert_response :unprocessable_content
    assert_select ".error-summary", text: /#{Regexp.escape(blank_message)}/
  end

  # 空欄と同じく「変更しない」として扱う。誤りとして示す場面ではない。
  test "空白だけのパスワードでの更新は現在の digest を保つ" do
    user = users(:hanako)
    digest_before = user.password_digest

    patch user_url(user), params: {
      user: { name: "佐藤 花子", password: " " * 15, password_confirmation: " " * 15 }
    }

    assert_redirected_to users_path
    assert_equal digest_before, user.reload.password_digest
  end

  test "15 文字に満たないパスワードへは変更できない" do
    user = users(:hanako)
    digest_before = user.password_digest

    patch user_url(user), params: {
      user: { password: "abcdefghijklmn", password_confirmation: "abcdefghijklmn" }
    }

    assert_response :unprocessable_content
    assert_equal digest_before, user.reload.password_digest
  end

  test "既知の初期値へは変更できない" do
    user = users(:hanako)
    digest_before = user.password_digest

    patch user_url(user), params: {
      user: { password: "change_me", password_confirmation: "change_me" }
    }

    assert_response :unprocessable_content
    assert_equal digest_before, user.reload.password_digest
  end

  test "パスワードを空にすると変更されない" do
    user = users(:hanako)
    digest_before = user.password_digest

    patch user_url(user), params: { user: { name: "佐藤 花子", password: "", password_confirmation: "" } }

    assert_redirected_to users_path
    assert_equal digest_before, user.reload.password_digest
  end

  test "パスワードを指定すると変更される" do
    user = users(:hanako)
    digest_before = user.password_digest

    patch user_url(user), params: {
      user: { password: "a-new-secret-value", password_confirmation: "a-new-secret-value" }
    }

    assert_not_equal digest_before, user.reload.password_digest
  end

  test "権限を変更できる" do
    patch user_url(users(:hanako)), params: { user: { role: "administrator" } }

    assert_predicate users(:hanako).reload, :administrator?
  end

  test "最後の管理者を一般利用者へ変更できない" do
    assert_no_difference -> { AuditEvent.where(action: "user_updated").count } do
      patch user_url(users(:taro)), params: { user: { role: "member" } }
    end

    assert_response :unprocessable_content
    assert_select ".error-summary", text: /#{Regexp.escape(last_active_administrator_message)}/
    assert_predicate users(:taro).reload, :administrator?
  end

  test "管理者が 2 人いれば一般利用者へ変更できる" do
    users(:hanako).update!(role: "administrator")

    assert_difference -> { AuditEvent.where(action: "user_updated").count }, 1 do
      patch user_url(users(:taro)), params: { user: { role: "member" } }
    end

    assert_redirected_to users_path
    assert_predicate users(:taro).reload, :member?
    assert_predicate users(:hanako).reload, :administrator?
  end

  test "別組織の利用者は編集できない" do
    get edit_user_url(users(:outsider))

    assert_response :not_found
  end

  test "一般利用者は利用者管理へ入れない" do
    sign_out
    sign_in_as users(:hanako)

    get users_url

    assert_response :forbidden
  end

  private
    def last_active_administrator_message
      I18n.t("activerecord.errors.models.user.attributes.base.last_active_administrator")
    end

    def blank_message
      I18n.t("errors.messages.blank")
    end

    def known_unsafe_message(locale = I18n.default_locale)
      I18n.t("activerecord.errors.models.user.attributes.password.known_unsafe", locale: locale)
    end
end
