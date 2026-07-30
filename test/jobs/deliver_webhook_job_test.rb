require "test_helper"
require_relative "../test_helpers/local_http_server_test_helper"

class DeliverWebhookJobTest < ActiveJob::TestCase
  include LocalHttpServerTestHelper

  setup do
    @endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")
  end

  # --- 送信時の再検証 ---

  test "送信のたびに名前解決をやり直す" do
    calls = []
    job = DeliverWebhookJob.new
    job.resolver = lambda do |hostname, port|
      calls << [ hostname, port ]
      [ "93.184.216.34" ]
    end

    job.perform(@endpoint.id, "request_submitted", { subject_id: 1 })

    assert_equal [ [ "example.com", 443 ] ], calls
  end

  test "保存時は外部でも、送信時に内部へ変わっていれば送らない" do
    job = DeliverWebhookJob.new
    # 保存時は 93.184.216.34、送信時はループバックへ変わった状況。
    job.resolver = ->(_hostname, _port) { [ "127.0.0.1" ] }

    assert_difference -> { WebhookDelivery.count }, 1 do
      job.perform(@endpoint.id, "request_submitted", { subject_id: 1 })
    end

    delivery = @endpoint.webhook_deliveries.recent_first.first

    assert_equal "destination_not_allowed", delivery.failure_code
    assert_nil delivery.response_status
    assert_nil delivery.delivered_at
    assert_predicate delivery, :rejected?
  end

  test "拒否した理由を符号で残す" do
    {
      "resolution_failed" => ->(_hostname, _port) { raise WebhookDestination::Error.new(:resolution_failed) },
      "resolution_timeout" => ->(_hostname, _port) { raise WebhookDestination::Error.new(:resolution_timeout) },
      "destination_not_allowed" => ->(_hostname, _port) { [ "10.0.0.1" ] }
    }.each do |expected, resolver|
      job = DeliverWebhookJob.new
      job.resolver = resolver

      job.perform(@endpoint.id, "request_submitted", { subject_id: 1 })

      assert_equal expected, @endpoint.webhook_deliveries.recent_first.first.failure_code
    end
  end

  test "許可されていないポートの宛先は送信時にも拒否する" do
    @endpoint.update_column(:url, "https://example.com:8443/hook")

    job = DeliverWebhookJob.new
    job.resolver = ->(_hostname, _port) { [ "93.184.216.34" ] }
    job.perform(@endpoint.id, "request_submitted", { subject_id: 1 })

    assert_equal "port_not_allowed", @endpoint.webhook_deliveries.recent_first.first.failure_code
  end

  test "記録に内部のアドレスを残さない" do
    job = DeliverWebhookJob.new
    job.resolver = ->(_hostname, _port) { [ "169.254.169.254" ] }

    job.perform(@endpoint.id, "request_submitted", { subject_id: 1 })
    delivery = @endpoint.webhook_deliveries.recent_first.first

    refute_includes delivery.attributes.values.map(&:to_s).join(" "), "169.254"
  end

  # --- 接続の組み立て ---

  test "接続先は検証済みの IP へ固定し、ホスト名はそのまま残す" do
    destination = WebhookDestination.resolve!(
      "https://hooks.example.com/events",
      resolver: ->(_hostname, _port) { [ "93.184.216.34" ] }
    )

    http = DeliverWebhookJob.new.send(:build_connection, destination)

    # Host ヘッダー、TLS の SNI、証明書の検証はホスト名を使う必要がある。
    assert_equal "hooks.example.com", http.address
    assert_equal "93.184.216.34", http.ipaddr
    assert_equal 443, http.port
  end

  test "proxy の環境変数を使わない" do
    original = ENV["http_proxy"]
    ENV["http_proxy"] = "http://proxy.example.invalid:3128"

    destination = WebhookDestination.resolve!(
      "http://hooks.example.com/events",
      resolver: ->(_hostname, _port) { [ "93.184.216.34" ] }
    )

    http = DeliverWebhookJob.new.send(:build_connection, destination)

    assert_not_predicate http, :proxy?
    assert_nil http.proxy_address
  ensure
    ENV["http_proxy"] = original
  end

  test "https では証明書とホスト名を検証する" do
    destination = WebhookDestination.resolve!(
      "https://hooks.example.com/events",
      resolver: ->(_hostname, _port) { [ "93.184.216.34" ] }
    )

    http = DeliverWebhookJob.new.send(:build_connection, destination)

    assert_predicate http, :use_ssl?
    assert_equal OpenSSL::SSL::VERIFY_PEER, http.verify_mode
    assert http.verify_hostname
  end

  test "待ち時間の上限を書き込みにも設ける" do
    destination = WebhookDestination.resolve!(
      "http://hooks.example.com/events",
      resolver: ->(_hostname, _port) { [ "93.184.216.34" ] }
    )

    http = DeliverWebhookJob.new.send(:build_connection, destination)

    assert_equal DeliverWebhookJob::OPEN_TIMEOUT, http.open_timeout
    assert_equal DeliverWebhookJob::READ_TIMEOUT, http.read_timeout
    assert_equal DeliverWebhookJob::WRITE_TIMEOUT, http.write_timeout
  end

  # --- 実際のソケット ---

  test "許可リストに無ければループバックへ接続しない" do
    address = loopback_address

    with_local_server(address) do |received|
      job = DeliverWebhookJob.new
      job.resolver = ->(_hostname, _port) { [ address ] }
      job.allowlist = Set.new

      job.perform(@endpoint.id, "request_submitted", { subject_id: 1 })

      assert_empty received.call, "拒否したのに接続している"
    end

    assert_equal "destination_not_allowed", @endpoint.webhook_deliveries.recent_first.first.failure_code
  end

  test "許可リストにある内部宛先へは送信できる" do
    address = loopback_address
    @endpoint.update_column(:url, "http://hooks.internal.example/events")

    with_local_server(address) do |received|
      job = DeliverWebhookJob.new
      job.resolver = ->(_hostname, _port) { [ address ] }
      job.allowlist = Set["http://hooks.internal.example:80"]

      job.perform(@endpoint.id, "request_submitted", { subject_id: 42 })

      requests = received.call

      assert_equal 1, requests.size
      request = requests.first

      assert_equal "POST /events HTTP/1.1", request.request_line
      # Host ヘッダーは接続先の IP ではなく、元のホスト名になる。
      assert_equal "hooks.internal.example", request.headers["host"]
      assert_equal "application/json", request.headers["content-type"]
      assert_equal @endpoint.signature_for(request.body), request.headers["x-officeweave-signature"]
      assert_equal({ "subject_id" => 42 }, JSON.parse(request.body))
    end

    delivery = @endpoint.webhook_deliveries.recent_first.first

    assert_equal 204, delivery.response_status
    assert_nil delivery.failure_code
    assert delivery.delivered_at.present?
  end

  test "3xx の Location へは追わない" do
    address = loopback_address(0)
    redirect_target = loopback_address(1)
    @endpoint.update_column(:url, "http://hooks.internal.example/events")

    with_local_server(redirect_target) do |target_received|
      with_local_server(address, status: "302 Found", location: "http://#{redirect_target}/moved") do |received|
        job = DeliverWebhookJob.new
        job.resolver = ->(_hostname, _port) { [ address ] }
        job.allowlist = Set["http://hooks.internal.example:80"]

        job.perform(@endpoint.id, "request_submitted", { subject_id: 1 })

        assert_equal 1, received.call.size
      end

      assert_empty target_received.call, "Location へ再接続している"
    end

    assert_equal 302, @endpoint.webhook_deliveries.recent_first.first.response_status
  end

  # --- 既存の契約 ---

  test "宛先へ到達できない場合も記録が残る" do
    @endpoint.update_column(:url, "https://example.invalid/hook")

    assert_difference -> { WebhookDelivery.count }, 1 do
      DeliverWebhookJob.perform_now(@endpoint.id, "request_submitted", { subject_id: 1 })
    end

    delivery = @endpoint.webhook_deliveries.recent_first.first

    assert_not_predicate delivery, :succeeded?
    # 解決できない宛先は、通信の前に拒否される。
    assert_equal "resolution_failed", delivery.failure_code
  end

  test "停止中の送信先へは送らない" do
    @endpoint.update!(active: false)

    assert_no_difference -> { WebhookDelivery.count } do
      DeliverWebhookJob.perform_now(@endpoint.id, "request_submitted", { subject_id: 1 })
    end
  end

  test "存在しない送信先でも失敗しない" do
    assert_nothing_raised do
      DeliverWebhookJob.perform_now(0, "request_submitted", { subject_id: 1 })
    end
  end
end
