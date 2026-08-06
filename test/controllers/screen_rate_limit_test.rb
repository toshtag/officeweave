require "test_helper"

# 画面側の上限。
#
# ログインとパスワード再設定は、資格情報を知らない相手が繰り返し試せる
# 入口である。数え上げはデータベースで共有し、web の台数に依存させない。
class ScreenRateLimitTest < ActionDispatch::IntegrationTest
  PASSWORD = "password-for-tests".freeze

  SIGN_IN_LIMIT = 10
  PASSWORD_RESET_LIMIT = 5

  test "ログインの試行が上限を超えると受け付けない" do
    SIGN_IN_LIMIT.times { post session_url, params: { email_address: "taro@example.com", password: "違う" } }
    assert_redirected_to new_session_path

    post session_url, params: { email_address: "taro@example.com", password: "違う" }

    assert_redirected_to new_session_path
    assert_equal I18n.t("sessions.rate_limited"), flash[:alert]
  end

  test "上限に達した後は、正しい資格情報でも受け付けない" do
    SIGN_IN_LIMIT.times { post session_url, params: { email_address: "taro@example.com", password: "違う" } }

    post session_url, params: { email_address: "taro@example.com", password: PASSWORD }

    assert_equal I18n.t("sessions.rate_limited"), flash[:alert]
    assert_nil cookies[:session_id].presence
  end

  test "時間の窓が終われば、ログインを再び受け付ける" do
    SIGN_IN_LIMIT.times { post session_url, params: { email_address: "taro@example.com", password: "違う" } }

    travel 4.minutes do
      post session_url, params: { email_address: "taro@example.com", password: PASSWORD }

      assert_redirected_to root_path
    end
  end

  test "パスワード再設定の要求が上限を超えると受け付けない" do
    PASSWORD_RESET_LIMIT.times { post password_resets_url, params: { email_address: "taro@example.com" } }

    post password_resets_url, params: { email_address: "taro@example.com" }

    assert_redirected_to new_password_reset_path
    assert_equal I18n.t("password_resets.rate_limited"), flash[:alert]
  end

  # 数え上げがデータベースにあることを、上限に達した状態から直接確かめる。
  # ここが空のままで上限が働くなら、数えている場所は web の内側である。
  test "数え上げは web の外で共有する置き場所に残る" do
    post session_url, params: { email_address: "taro@example.com", password: "違う" }

    assert_equal 1, RateLimitCounter.where("key LIKE ?", "%sessions%").count
  end
end
