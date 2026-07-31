require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = users(:taro) }

  test "ログイン画面は認証なしで表示できる" do
    get new_session_path

    assert_response :success
  end

  test "正しい資格情報でログインできる" do
    post session_path, params: { email_address: @user.email_address, password: "password-for-tests" }

    assert_redirected_to root_path
    assert cookies[:session_id].present?
  end

  test "大文字と前後の空白の違いを吸収してログインできる" do
    post session_path, params: { email_address: "  TARO@Example.com  ", password: "password-for-tests" }

    assert_redirected_to root_path
  end

  test "誤ったパスワードではログインできない" do
    post session_path, params: { email_address: @user.email_address, password: "wrong-password" }

    assert_redirected_to new_session_path
    assert cookies[:session_id].blank?
  end

  test "存在しない利用者と誤ったパスワードで応答が変わらない" do
    post session_path, params: { email_address: "nobody@example.com", password: "wrong-password" }
    missing_user_flash = flash[:alert]

    post session_path, params: { email_address: @user.email_address, password: "wrong-password" }

    assert_equal missing_user_flash, flash[:alert]
  end

  test "ログアウトするとセッションが破棄される" do
    sign_in_as(@user)

    assert_difference -> { Session.count }, -1 do
      delete session_path
    end

    assert_redirected_to new_session_path
  end

  test "ログインしていない場合は保護された画面から追い返される" do
    get root_url

    assert_redirected_to new_session_path
  end

  test "ログイン後は元の画面へ戻る" do
    get root_url
    assert_redirected_to new_session_path

    post session_path, params: { email_address: @user.email_address, password: "password-for-tests" }

    assert_redirected_to root_url
  end

  test "ログインで発行する Cookie に有限の有効期限が付く" do
    sign_in_with_password

    assert session_cookie_expiry, "session_id に有効期限が付いていない"
    assert_operator session_cookie_expiry, :<=, 8.hours.from_now + 1.minute
  end

  test "Cookie の有効期限はログインから 8 時間後になる" do
    travel_to Time.zone.parse("2026-07-31 09:00:00") do
      sign_in_with_password

      assert_equal 8.hours.from_now.to_i, session_cookie_expiry.to_i
    end
  end

  test "Cookie に HttpOnly が付く" do
    sign_in_with_password

    assert_match(/;\s*httponly/i, session_cookie)
  end

  test "Cookie に SameSite=Lax が付く" do
    sign_in_with_password

    assert_match(/;\s*samesite=lax/i, session_cookie)
  end

  test "暗号化された要求で発行した Cookie に Secure が付く" do
    https!
    sign_in_with_password

    assert_match(/;\s*secure/i, session_cookie)
  end

  test "操作を続けていても絶対期限を過ぎると保護された画面へ到達できない" do
    sign_in_as(@user)

    # 無操作期限に掛からない間隔で操作を続ける。7 時間 55 分まで到達する。
    (1..19).each do |interval|
      travel interval * 25.minutes do
        get root_url
        assert_response :success
      end
    end

    travel 8.hours + 1.minute do
      get root_url

      assert_redirected_to new_session_path
    end
  end

  test "無操作のまま 30 分を過ぎたセッションでは保護された画面へ到達できない" do
    sign_in_as(@user)

    travel 31.minutes do
      get root_url

      assert_redirected_to new_session_path
    end
  end

  test "操作を続けていれば無操作期限では終わらない" do
    sign_in_as(@user)

    travel 20.minutes do
      get root_url
      assert_response :success
    end

    travel 40.minutes do
      get root_url

      assert_response :success
    end
  end

  test "期限切れのセッションは記録ごと破棄される" do
    sign_in_as(@user)

    travel 31.minutes do
      assert_difference -> { Session.count }, -1 do
        get root_url
      end
    end
  end

  test "期限切れのセッションでは Cookie も削除される" do
    sign_in_as(@user)

    travel 31.minutes do
      get root_url

      assert cookies[:session_id].blank?, "期限切れの後も session_id が残っている"
    end
  end

  private
    def sign_in_with_password
      post session_path, params: { email_address: @user.email_address, password: "password-for-tests" }
    end

    # Set-Cookie は複数の値を返す。session_id の 1 件だけを取り出す。
    def session_cookie
      headers = response.headers["set-cookie"]
      entries = headers.is_a?(Array) ? headers : headers.to_s.split("\n")

      entries.find { |entry| entry.start_with?("session_id=") }.to_s
    end

    def session_cookie_expiry
      matched = session_cookie[/expires=([^;]+)/i, 1]

      Time.parse(matched) if matched
    end
end
