require "test_helper"

class ApiTokensControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:hanako) }

  test "token を発行できる" do
    assert_difference -> { ApiToken.count }, 1 do
      post api_tokens_url, params: { api_token: { name: "連携用", scopes: ApiToken::SCOPES } }
    end

    assert_equal users(:hanako), ApiToken.last.user
  end

  test "発行した値は一度だけ表示される" do
    post api_tokens_url, params: { api_token: { name: "連携用", scopes: ApiToken::SCOPES } }
    follow_redirect!

    assert_select ".token"

    get api_tokens_url

    assert_select ".token", count: 0
  end

  test "自分の token だけが並ぶ" do
    other = organizations(:main).api_tokens.create!(user: users(:taro), name: "他人の token", scopes: ApiToken::SCOPES)

    get api_tokens_url

    assert_select "td", text: "他人の token", count: 0
    assert_not_nil other
  end

  test "他人の token は無効にできない" do
    other = organizations(:main).api_tokens.create!(user: users(:taro), name: "他人の token", scopes: ApiToken::SCOPES)

    delete api_token_url(other)

    assert_response :not_found
    assert_not_predicate other.reload, :revoked?
  end

  test "自分の token は無効にできる" do
    token = organizations(:main).api_tokens.create!(user: users(:hanako), name: "連携用", scopes: ApiToken::SCOPES)

    delete api_token_url(token)

    assert_predicate token.reload, :revoked?
  end
end
