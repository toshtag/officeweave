require "test_helper"

class WebhookEndpointTest < ActiveSupport::TestCase
  test "名前と URL があれば登録できる" do
    endpoint = organizations(:main).webhook_endpoints.new(name: "連携先", url: "https://example.com/hook")

    assert endpoint.valid?
  end

  test "署名に使う値が自動で作られる" do
    endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")

    assert endpoint.secret.present?
  end

  test "http または https 以外は登録できない" do
    endpoint = organizations(:main).webhook_endpoints.new(name: "連携先", url: "ftp://example.com/hook")

    assert_not endpoint.valid?
  end

  test "改行を挟んだ値は登録できない" do
    endpoint = organizations(:main).webhook_endpoints.new(name: "連携先", url: "https://example.com\nevil")

    assert_not endpoint.valid?
  end

  test "宛先のない URL は登録できない" do
    endpoint = organizations(:main).webhook_endpoints.new(name: "連携先", url: "https://")

    assert_not endpoint.valid?
  end

  test "署名は受け取る側で同じ計算になる" do
    endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")
    payload = '{"event":"announcement_published"}'

    expected = OpenSSL::HMAC.hexdigest("SHA256", endpoint.secret, payload)

    assert_equal expected, endpoint.signature_for(payload)
  end
end
