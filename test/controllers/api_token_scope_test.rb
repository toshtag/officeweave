require "test_helper"

# API トークンの範囲を、画面と外部からの接続の側から確かめる。
class ApiTokenScopeRequestTest < ActionDispatch::IntegrationTest
  test "範囲を選んで発行できる" do
    sign_in_as users(:taro)

    post api_tokens_url, params: {
      api_token: { name: "予定の連携", expires_in_days: "90", scopes: %w[events] }
    }

    assert_redirected_to api_tokens_path
    assert_equal %w[events], ApiToken.recent_first.first.scopes
  end

  test "範囲を選ばずには発行できない" do
    sign_in_as users(:taro)

    assert_no_difference -> { ApiToken.count } do
      post api_tokens_url, params: { api_token: { name: "範囲なし", expires_in_days: "90" } }
    end

    assert_response :unprocessable_content
  end

  test "範囲の内側は読める" do
    token = issue(scopes: %w[events])

    get api_v1_events_url, headers: authorization(token)

    assert_response :success
  end

  test "範囲の外は読めない" do
    token = issue(scopes: %w[events])

    get api_v1_announcements_url, headers: authorization(token)

    assert_response :forbidden
    assert_equal "forbidden_scope", response.parsed_body["error"]
    # どの範囲が足りないのかを示す。呼び出す側が、発行し直す判断をできる。
    assert_equal "announcements", response.parsed_body["scope"]
  end

  test "範囲を持たない token はすべて読める" do
    token = issue(scopes: nil)

    ApiToken::SCOPES.each do |scope|
      get url_for_scope(scope), headers: authorization(token)

      # 利用者の一覧は管理者の token だけが読める。範囲とは別の判定である。
      assert_response :success, scope
    end
  end

  test "範囲を許しても、管理者でなければ利用者の一覧は読めない" do
    member = users(:hanako)
    token = member.api_tokens.create!(organization: member.organization, name: "一般",
                                      scopes: %w[users])

    get api_v1_users_url, headers: authorization(token)

    assert_response :forbidden
    assert_equal "forbidden", response.parsed_body["error"]
  end

  test "範囲の判定は認証の後に行う" do
    # 値が違えば、範囲の話をする前に 401 とする。
    get api_v1_events_url, headers: { "Authorization" => "Bearer not-a-real-token" }

    assert_response :unauthorized
  end

  test "一覧に範囲が出る" do
    token = issue(scopes: %w[announcements events])
    sign_in_as users(:taro)

    get api_tokens_url

    assert_select "[data-api-token-id='#{token.id}']",
                  text: /#{I18n.t('api_tokens.scopes.announcements')}/
  end

  test "範囲を持たない token は、すべてと示す" do
    token = issue(scopes: nil)
    sign_in_as users(:taro)

    get api_tokens_url

    assert_select "[data-api-token-id='#{token.id}']", text: /#{I18n.t('api_tokens.all_scopes')}/
  end

  test "発行の記録に範囲を残す" do
    sign_in_as users(:taro)

    post api_tokens_url, params: {
      api_token: { name: "予定の連携", expires_in_days: "90", scopes: %w[events announcements] }
    }

    event = AuditEvent.with_action("api_token_issued").recent_first.first

    assert_equal %w[announcements events], event.details["scopes"]
  end

  private
    def issue(scopes:)
      users(:taro).api_tokens.create!(organization: organizations(:main), name: "検証用", scopes: scopes)
    end

    def authorization(token)
      { "Authorization" => "Bearer #{token.token}" }
    end

    def url_for_scope(scope)
      { "announcements" => api_v1_announcements_url, "events" => api_v1_events_url,
        "departments" => api_v1_departments_url, "users" => api_v1_users_url }.fetch(scope)
    end
end
