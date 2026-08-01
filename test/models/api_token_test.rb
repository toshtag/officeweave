require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "発行すると値が一度だけ参照できる" do
    token = organizations(:main).api_tokens.create!(user: users(:taro), name: "連携用")

    assert token.token.present?
    assert_nil ApiToken.find(token.id).token
  end

  test "値そのものは保存しない" do
    token = organizations(:main).api_tokens.create!(user: users(:taro), name: "連携用")

    assert_not_equal token.token, token.token_digest
    assert_equal ApiToken.digest(token.token), token.token_digest
  end

  test "正しい値で認証できる" do
    token = organizations(:main).api_tokens.create!(user: users(:taro), name: "連携用")

    assert_equal token, ApiToken.authenticate(token.token)
  end

  test "認証すると最終利用が記録される" do
    token = organizations(:main).api_tokens.create!(user: users(:taro), name: "連携用")

    assert_nil token.last_used_at

    ApiToken.authenticate(token.token)

    assert_not_nil token.reload.last_used_at
  end

  test "無効にした token では認証できない" do
    token = organizations(:main).api_tokens.create!(user: users(:taro), name: "連携用")
    token.revoke!

    assert_nil ApiToken.authenticate(token.token)
  end

  test "無効にされた利用者の token では認証できない" do
    token = organizations(:main).api_tokens.create!(user: users(:hanako), name: "連携用")
    users(:hanako).deactivate!

    assert_nil ApiToken.authenticate(token.token)
  end

  # 認証時に利用者の状態を見るだけでは、再び有効にした時点で
  # 無効化前の値がそのまま使えるようになる。
  test "再び有効にしても無効化前の token では認証できない" do
    token = organizations(:main).api_tokens.create!(user: users(:hanako), name: "連携用")
    value = token.token

    users(:hanako).deactivate!
    users(:hanako).activate!

    assert_nil ApiToken.authenticate(value)
  end

  test "知らない値では認証できない" do
    assert_nil ApiToken.authenticate("unknown-token-value")
    assert_nil ApiToken.authenticate(nil)
    assert_nil ApiToken.authenticate("")
  end
end
