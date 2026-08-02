require "test_helper"

# API のレート制限。
#
# 数え上げはキャッシュ領域に保持する。試験環境の既定は数えない置き場所で
# あるため、この試験のあいだだけ数える置き場所へ差し替える。
class Api::V1::ApiRateLimitTest < ActionDispatch::IntegrationTest
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @token = users(:taro).api_tokens.create!(organization: organizations(:main), name: "検証", scopes: nil)
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "上限を超えると受け付けない" do
    limit = Api::BaseController::REQUESTS_PER_MINUTE

    limit.times { get api_v1_announcements_url, headers: authorization(@token) }
    assert_response :success

    get api_v1_announcements_url, headers: authorization(@token)

    assert_response :too_many_requests
    assert_equal "rate_limited", response.parsed_body["error"]
  end

  test "数えるのは token ごととする" do
    other = users(:taro).api_tokens.create!(organization: organizations(:main), name: "別の token",
                                            scopes: nil)
    Api::BaseController::REQUESTS_PER_MINUTE.times { get api_v1_announcements_url, headers: authorization(@token) }

    get api_v1_announcements_url, headers: authorization(other)

    # 同じ経路の別の token を巻き込まない。
    assert_response :success
  end

  test "時間が経てば受け付ける" do
    limit = Api::BaseController::REQUESTS_PER_MINUTE
    limit.times { get api_v1_announcements_url, headers: authorization(@token) }

    travel 2.minutes do
      get api_v1_announcements_url, headers: authorization(@token)

      assert_response :success
    end
  end

  test "値が違う要求は数える前に拒む" do
    # 認証の後に数える。値が違う要求で上限を使い切れないようにする。
    get api_v1_announcements_url, headers: { "Authorization" => "Bearer not-a-real-token" }

    assert_response :unauthorized
  end

  private
    def authorization(token) = { "Authorization" => "Bearer #{token.token}" }
end
