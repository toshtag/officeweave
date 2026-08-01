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

  test "送信先の変更を監査記録へ残す" do
    sign_in_as users(:taro)
    endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")

    assert_difference -> { AuditEvent.count }, 1 do
      patch webhook_endpoint_url(endpoint),
            params: { webhook_endpoint: { url: "https://hooks.example.com/moved" } }
    end

    event = AuditEvent.recent_first.first

    assert_equal "webhook_endpoint_updated", event.action
    assert_equal users(:taro), event.actor
    assert_equal endpoint, event.target
    assert_equal "https://example.com/hook", event.details["previous_url"]
    assert_equal "https://hooks.example.com/moved", event.details["url"]
  end

  test "停止と再開も監査記録へ残す" do
    sign_in_as users(:taro)
    endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")

    assert_difference -> { AuditEvent.count }, 1 do
      patch webhook_endpoint_url(endpoint), params: { webhook_endpoint: { active: "0" } }
    end

    event = AuditEvent.recent_first.first

    assert_equal "webhook_endpoint_updated", event.action
    assert_equal false, event.details["active"]
    assert_equal true, event.details["previous_active"]
  end

  test "値の変わらない保存では監査記録が増えない" do
    sign_in_as users(:taro)
    endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")

    assert_no_difference -> { AuditEvent.count } do
      patch webhook_endpoint_url(endpoint),
            params: { webhook_endpoint: { name: endpoint.name, url: endpoint.url, active: "1" } }
    end
  end

  test "保存できなかった変更は監査記録へ残さない" do
    sign_in_as users(:taro)
    endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")

    assert_no_difference -> { AuditEvent.count } do
      patch webhook_endpoint_url(endpoint), params: { webhook_endpoint: { url: "not-a-url" } }
    end

    assert_equal "https://example.com/hook", endpoint.reload.url
  end

  test "監査記録に送信先の secret を含めない" do
    sign_in_as users(:taro)
    endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")

    patch webhook_endpoint_url(endpoint),
          params: { webhook_endpoint: { url: "https://hooks.example.com/moved" } }

    assert_not_includes AuditEvent.recent_first.first.details.to_json, endpoint.secret
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
