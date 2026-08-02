require "test_helper"

# API トークンの有効期限を、画面と外部からの接続の側から確かめる。
class ApiTokenExpiryRequestTest < ActionDispatch::IntegrationTest
  test "期限を選んで発行できる" do
    sign_in_as users(:taro)

    post api_tokens_url, params: { api_token: { name: "集計", expires_in_days: "90", scopes: %w[events] } }

    assert_redirected_to api_tokens_path
    assert_in_delta 90.days.from_now, ApiToken.recent_first.first.expires_at, 1.minute
  end

  test "期限なしを選べる" do
    sign_in_as users(:taro)

    post api_tokens_url, params: { api_token: { name: "常設", expires_in_days: "", scopes: %w[events] } }

    assert_redirected_to api_tokens_path
    assert_nil ApiToken.recent_first.first.expires_at
  end

  test "候補にない日数は受け付けない" do
    sign_in_as users(:taro)

    assert_no_difference -> { ApiToken.count } do
      post api_tokens_url, params: { api_token: { name: "十年", expires_in_days: "3650", scopes: %w[events] } }
    end

    assert_response :unprocessable_content
  end

  test "既定では期限のある token を発行する" do
    sign_in_as users(:taro)

    get api_tokens_url

    # 期限なしを既定にすると、期限を選べることに気付かないまま発行される。
    assert_select "select[name='api_token[expires_in_days]'] option[selected]",
                  value: ApiToken::DEFAULT_EXPIRY_DAYS.to_s
  end

  test "一覧に期限と状態が出る" do
    sign_in_as users(:taro)
    token = users(:taro).api_tokens.create!(organization: organizations(:main), name: "期限つき",
                                            expires_at: 3.days.from_now)

    get api_tokens_url

    assert_select "[data-api-token-id='#{token.id}']",
                  text: /#{I18n.l(token.expires_at.to_date, format: :long)}/
  end

  test "期限を過ぎた token は、期限切れとして示す" do
    token = users(:taro).api_tokens.create!(organization: organizations(:main), name: "切れた",
                                            expires_at: 1.day.from_now)

    travel 2.days do
      # ログインは進めた時刻で行う。セッションの絶対期限は 8 時間であり、
      # 先にログインすると、時刻を進めた時点でログイン画面へ戻る。
      sign_in_as users(:taro)
      get api_tokens_url

      assert_select "[data-api-token-id='#{token.id}']", text: /#{I18n.t('api_tokens.status.expired')}/
    end
  end

  test "期限を過ぎた token では API を使えない" do
    token = users(:taro).api_tokens.create!(organization: organizations(:main), name: "切れた",
                                            expires_at: 1.day.from_now)
    value = token.token

    travel 2.days do
      get api_v1_announcements_url, headers: { "Authorization" => "Bearer #{value}" }

      assert_response :unauthorized
      assert_equal "unauthorized", response.parsed_body["error"]
    end
  end

  test "期限の内側なら API を使える" do
    token = users(:taro).api_tokens.create!(organization: organizations(:main), name: "有効",
                                            expires_at: 2.days.from_now)

    get api_v1_announcements_url, headers: { "Authorization" => "Bearer #{token.token}" }

    assert_response :success
  end

  test "発行の記録に期限を残す" do
    sign_in_as users(:taro)

    post api_tokens_url, params: { api_token: { name: "集計", expires_in_days: "30", scopes: %w[events] } }

    event = AuditEvent.with_action("api_token_issued").recent_first.first

    # いつまで使える token を発行したのかが分からないと、後から範囲を確かめられない。
    assert_equal 30, event.details["expires_in_days"]
  end
end
