require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  include QueryCountTestHelper

  test "発行すると値が一度だけ参照できる" do
    token = organizations(:main).api_tokens.create!(user: users(:taro), name: "連携用", scopes: ApiToken::SCOPES)

    assert token.token.present?
    assert_nil ApiToken.find(token.id).token
  end

  test "値そのものは保存しない" do
    token = organizations(:main).api_tokens.create!(user: users(:taro), name: "連携用", scopes: ApiToken::SCOPES)

    assert_not_equal token.token, token.token_digest
    assert_equal ApiToken.digest(token.token), token.token_digest
  end

  test "正しい値で認証できる" do
    token = organizations(:main).api_tokens.create!(user: users(:taro), name: "連携用", scopes: ApiToken::SCOPES)

    assert_equal token, ApiToken.authenticate(token.token)
  end

  test "認証すると最終利用が記録される" do
    token = organizations(:main).api_tokens.create!(user: users(:taro), name: "連携用", scopes: ApiToken::SCOPES)

    assert_nil token.last_used_at

    ApiToken.authenticate(token.token)

    assert_not_nil token.reload.last_used_at
  end

  test "短い間隔で続けて認証しても最終利用を書き込まない" do
    token = organizations(:main).api_tokens.create!(user: users(:taro), name: "連携用", scopes: ApiToken::SCOPES)
    value = token.token
    ApiToken.authenticate(value)
    recorded_at = token.reload.last_used_at

    ApiToken.authenticate(value)

    assert_equal recorded_at, token.reload.last_used_at
  end

  test "間隔を超えると最終利用が記録される" do
    token = organizations(:main).api_tokens.create!(user: users(:taro), name: "連携用", scopes: ApiToken::SCOPES)
    value = token.token
    ApiToken.authenticate(value)

    travel(ApiToken::USE_WRITE_INTERVAL + 1.second) do
      ApiToken.authenticate(value)

      assert_in_delta Time.current, token.reload.last_used_at, 1.second
    end
  end

  # 利用者の状態は認証のたびに見る。別の問い合わせにすると、外部からの接続
  # 1 回につき往復が 1 つ増える。
  test "認証は 1 回の問い合わせで済む" do
    token = organizations(:main).api_tokens.create!(user: users(:taro), name: "連携用", scopes: ApiToken::SCOPES)
    value = token.token
    ApiToken.authenticate(value)

    assert_equal 1, count_queries { ApiToken.authenticate(value) }
  end

  test "無効にした token では認証できない" do
    token = organizations(:main).api_tokens.create!(user: users(:taro), name: "連携用", scopes: ApiToken::SCOPES)
    token.revoke!

    assert_nil ApiToken.authenticate(token.token)
  end

  test "無効にされた利用者の token では認証できない" do
    token = organizations(:main).api_tokens.create!(user: users(:hanako), name: "連携用", scopes: ApiToken::SCOPES)
    users(:hanako).deactivate!

    assert_nil ApiToken.authenticate(token.token)
  end

  # 認証時に利用者の状態を見るだけでは、再び有効にした時点で
  # 無効化前の値がそのまま使えるようになる。
  test "再び有効にしても無効化前の token では認証できない" do
    token = organizations(:main).api_tokens.create!(user: users(:hanako), name: "連携用", scopes: ApiToken::SCOPES)
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

  test "無効にされた利用者へは発行できない" do
    users(:hanako).deactivate!
    token = organizations(:main).api_tokens.new(user: users(:hanako), name: "連携用", scopes: ApiToken::SCOPES)

    assert_not token.save
    assert_includes token.errors.details[:user], { error: :inactive }
    assert_predicate token, :new_record?
    assert_empty users(:hanako).api_tokens
  end

  # 検査を検証へ置くと、検証を省いた保存では素通りする。
  test "検証を省いても無効にされた利用者へは発行できない" do
    users(:hanako).deactivate!
    token = organizations(:main).api_tokens.new(user: users(:hanako), name: "連携用", scopes: ApiToken::SCOPES)

    assert_not token.save(validate: false)
    assert_predicate token, :new_record?
    assert_empty users(:hanako).api_tokens
  end

  test "再び有効にした利用者は新しい token を発行できる" do
    previous = organizations(:main).api_tokens.create!(user: users(:hanako), name: "連携用", scopes: ApiToken::SCOPES)
    previous_value = previous.token

    users(:hanako).deactivate!
    users(:hanako).activate!
    reissued = organizations(:main).api_tokens.create!(user: users(:hanako), name: "再発行", scopes: ApiToken::SCOPES)

    assert_equal reissued, ApiToken.authenticate(reissued.token)
    assert_nil ApiToken.authenticate(previous_value)
  end
end
