require "test_helper"

class WebhookEndpointsControllerTest < ActionDispatch::IntegrationTest
  test "管理者は送信先を登録できる" do
    sign_in_as users(:taro)

    assert_difference -> { WebhookEndpoint.count }, 1 do
      post webhook_endpoints_url, params: {
        webhook_endpoint: { name: "連携先", url: "https://example.com/hook" }
      }
    end
  end

  test "一般利用者は送信先を扱えない" do
    sign_in_as users(:hanako)

    get webhook_endpoints_url

    assert_response :forbidden
  end

  test "形式が正しくない URL は登録できない" do
    sign_in_as users(:taro)

    assert_no_difference -> { WebhookEndpoint.count } do
      post webhook_endpoints_url, params: { webhook_endpoint: { name: "連携先", url: "not-a-url" } }
    end

    assert_response :unprocessable_content
  end

  test "停止と再開ができる" do
    sign_in_as users(:taro)
    endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")

    patch webhook_endpoint_url(endpoint), params: { webhook_endpoint: { active: "0" } }

    assert_not_predicate endpoint.reload, :active?
  end

  test "別組織の送信先は扱えない" do
    sign_in_as users(:taro)
    other = organizations(:other).webhook_endpoints.create!(name: "別組織", url: "https://example.com/hook")

    delete webhook_endpoint_url(other)

    assert_response :not_found
  end

  test "送信の記録を確認できる" do
    sign_in_as users(:taro)
    endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")
    endpoint.webhook_deliveries.create!(event: "request_submitted", response_status: 200, delivered_at: Time.current)

    get webhook_endpoint_url(endpoint)

    assert_response :success
    assert_select "#webhook-deliveries"
  end
end
