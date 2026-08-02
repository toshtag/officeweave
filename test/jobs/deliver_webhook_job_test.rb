require "test_helper"
require_relative "../test_helpers/local_http_server_test_helper"

class DeliverWebhookJobTest < ActiveJob::TestCase
  include LocalHttpServerTestHelper

  setup do
    @endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")
  end

  # --- 送信時の再検証 ---

  test "送信のたびに名前解決をやり直す" do
    address = loopback_address(4)
    @endpoint.update_column(:url, "http://hooks.internal.example/events")
    calls = []

    with_local_server(address) do |_received|
      job = DeliverWebhookJob.new
      job.allowlist = Set["http://hooks.internal.example:80"]
      job.resolver = lambda do |hostname, port|
        calls << [ hostname, port ]
        [ address ]
      end

      job.perform(@endpoint.id, "request_submitted", { subject_id: 1 })
      job.perform(@endpoint.id, "request_submitted", { subject_id: 1 })
    end

    # 送信のたびに解決する。保存時の結果を持ち回さない。
    assert_equal [ [ "hooks.internal.example", 80 ], [ "hooks.internal.example", 80 ] ], calls
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

  # --- 受け取る量の上限 ---
  #
  # 使うのは応答の状態だけである。上限は本文だけでなく、ステータス行と
  # ヘッダーを含む受け取り全体に掛ける。本文だけを数えると、宛先は
  # ヘッダーへ同じ量を積んで同じ負荷を作れる。
  #
  # 読み切ってから大きさを見る形にはしない。その時点で確保が済んでいる。
  # 上限を超えた分を読まないことを、受け取る側が書き込めた量で確かめる。

  # 上限を十分に超え、かつソケットの緩衝より大きい量。
  # 緩衝へ収まる量だと、送信側が読むのをやめても最後まで書けてしまい、
  # 打ち切ったのか元から短いのかを区別できない。
  OVERSIZED_BYTES = 33 * 1024 * 1024

  # 打ち切れていれば、書き込めた量はこれを下回る。
  # ソケットの緩衝の分だけ上限より多く書けるため、余裕を持たせる。
  TRUNCATED_BYTES = 4 * 1024 * 1024

  test "上限は応答として妥当な大きさに収まる" do
    assert_operator DeliverWebhookJob::MAXIMUM_RESPONSE_BYTES, :<, TRUNCATED_BYTES
    assert_operator TRUNCATED_BYTES, :<, OVERSIZED_BYTES
  end

  test "巨大なステータス行を上限で打ち切る" do
    written = deliver_to_local_server(status: "200 応答", status_line_bytes: OVERSIZED_BYTES)

    assert_operator written, :<, TRUNCATED_BYTES, "ステータス行を読み進めている"
    assert_oversized_failure
  end

  test "巨大な単一ヘッダーを上限で打ち切る" do
    written = deliver_to_local_server(status: "200 応答", single_header_bytes: OVERSIZED_BYTES)

    assert_operator written, :<, TRUNCATED_BYTES, "ヘッダーを読み進めている"
    assert_oversized_failure
  end

  test "ヘッダーの総量を上限で打ち切る" do
    written = deliver_to_local_server(status: "200 応答", header_bytes: OVERSIZED_BYTES)

    assert_operator written, :<, TRUNCATED_BYTES, "ヘッダーを読み進めている"
    assert_oversized_failure
  end

  test "上限を超える本文は打ち切り、状態は記録する" do
    written = deliver_to_local_server(status: "200 応答", body_bytes: OVERSIZED_BYTES)

    assert_operator written, :<, TRUNCATED_BYTES, "本文を読み進めている"
    assert_equal 200, @endpoint.webhook_deliveries.recent_first.first.response_status
  end

  test "Content-Length の無い応答も同じ上限で打ち切る" do
    written = deliver_to_local_server(status: "200 応答", body_bytes: OVERSIZED_BYTES, chunked: true)

    assert_operator written, :<, TRUNCATED_BYTES, "chunked を読み進めている"
    assert_equal 200, @endpoint.webhook_deliveries.recent_first.first.response_status
  end

  test "上限に収まる応答は最後まで受け取る" do
    body_bytes = DeliverWebhookJob::MAXIMUM_RESPONSE_BYTES / 2
    written = deliver_to_local_server(status: "200 応答", body_bytes: body_bytes)

    # written はステータス行とヘッダーも含む。打ち切られていれば本文の量を下回る。
    assert_operator written, :>=, body_bytes, "上限に収まる本文を打ち切っている"
    assert_equal 200, @endpoint.webhook_deliveries.recent_first.first.response_status
  end

  test "本文の無い応答は従来どおり成功として記録する" do
    deliver_to_local_server(status: "204 応答")

    delivery = @endpoint.webhook_deliveries.recent_first.first

    assert_equal 204, delivery.response_status
    assert_nil delivery.failure_code
    assert_nil delivery.error_message
    assert delivery.delivered_at.present?
  end

  test "chunk の後書きも上限の中で扱う" do
    deliver_to_local_server(status: "200 応答", body_bytes: 64, chunked: true, trailer: true)

    delivery = @endpoint.webhook_deliveries.recent_first.first

    assert_equal 200, delivery.response_status
    assert_nil delivery.error_message
  end

  test "圧縮した応答を要求しない" do
    request = nil
    @endpoint.update_column(:url, "http://hooks.internal.example/events")

    with_local_server(loopback_address(2), status: "204 応答") do |received|
      perform_to(loopback_address(2))
      request = received.call.first
    end

    # 展開を伴うと、圧縮された小さい応答から大きな確保が起きる。
    # 上限は受け取った byte に掛かるため、展開後の量には効かない。
    assert_equal "identity", request.headers["accept-encoding"]
  end

  test "宛先が圧縮して返しても展開しない" do
    # 展開する実装なら、この応答は圧縮の誤りとして例外になり状態が残らない。
    deliver_to_local_server(status: "200 応答", content_encoding: "gzip", broken_encoding: true)

    delivery = @endpoint.webhook_deliveries.recent_first.first

    assert_equal 200, delivery.response_status
    assert_nil delivery.error_message
  end

  test "上限を超えたことをやり直しの理由にしない" do
    # 200 は元からやり直さない。上限で打ち切っても、その判断を変えない。
    assert_nothing_raised do
      deliver_to_local_server(status: "200 応答", body_bytes: OVERSIZED_BYTES)
    end

    assert_nothing_raised do
      deliver_to_local_server(status: "500 応答", status_line_bytes: OVERSIZED_BYTES)
    end

    assert_oversized_failure
  end

  test "5xx でも本文を読み切らずに記録し、やり直しへ渡す" do
    written = deliver_to_local_server(status: "500 応答", body_bytes: OVERSIZED_BYTES,
                                      expect: DeliverWebhookJob::TransientDeliveryError)

    assert_operator written, :<, TRUNCATED_BYTES, "本文を読み進めている"
    assert_equal 500, @endpoint.webhook_deliveries.recent_first.first.response_status
  end

  test "上限を超えた記録に宛先を残さない" do
    deliver_to_local_server(status: "200 応答", status_line_bytes: OVERSIZED_BYTES)

    message = @endpoint.webhook_deliveries.recent_first.first.error_message

    refute_includes message, "hooks.internal.example"
    refute_includes message, loopback_address(2)
    refute_includes message, "80"
  end

  test "上限で打ち切っても実行単位と socket が増えない" do
    skip "/proc を読めない環境では測れない" unless File.directory?("/proc/self/fd")

    address = loopback_address(2)
    @endpoint.update_column(:url, "http://hooks.internal.example/events")

    with_local_server(address, status: "200 応答", status_line_bytes: 1024 * 1024) do
      5.times { perform_to(address) }
      before = process_resources
      50.times { perform_to(address) }

      assert_equal before, process_resources, "打ち切りのたびに資源が残っている"
    end
  end

  # --- 通信全体の期限 ---
  #
  # 待ち時間の上限は 1 回の読み取りに効く。それより短い間隔で少しずつ
  # 返し続ける宛先は、上限に掛からないまま worker を占有できる。
  # 期限は、要求の開始から終了までの経過で判定する。

  # 4096 byte を 16 byte ずつ 0.1 秒間隔で返す。
  # 1 回の読み取りは待ち時間の上限に収まるが、読み切るには 25 秒以上かかる。
  SLOW_RESPONSE = { body_bytes: 4096, chunked: true, chunk_bytes: 16, chunk_delay: 0.1 }.freeze

  test "期限は 1 回の読み取りの上限より長い" do
    # 1 回の読み取りが止まった場合は、こちらではなく待ち時間の上限で切れる。
    # 逆にすると、一時的な停止までやり直さない失敗になってしまう。
    assert_operator DeliverWebhookJob::TOTAL_DEADLINE, :>, DeliverWebhookJob::READ_TIMEOUT
  end

  test "少しずつ返し続ける応答を期限で打ち切る" do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    written = deliver_to_local_server(status: "200 応答", deadline: 0.5, **SLOW_RESPONSE)

    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    assert_operator elapsed, :<, 10, "期限で打ち切っていない"
    assert_operator written, :<, SLOW_RESPONSE[:body_bytes], "本文を最後まで読んでいる"
  end

  test "期限を超えた送信を、宛先を残さない失敗として記録する" do
    deliver_to_local_server(status: "200 応答", deadline: 0.5, **SLOW_RESPONSE)

    delivery = @endpoint.webhook_deliveries.recent_first.first

    assert delivery.error_message.present?
    refute_includes delivery.error_message, "hooks.internal.example"
    assert_nil delivery.response_status
    assert_nil delivery.delivered_at
  end

  test "期限の超過ではやり直さない" do
    # やり直す応答を返す宛先でも、期限で切れた場合はやり直さない。
    # やり直すと、同じ占有を最大 5 回繰り返すことになる。
    assert_nothing_raised do
      deliver_to_local_server(status: "500 応答", deadline: 0.5, **SLOW_RESPONSE)
    end
  end

  test "期限の超過を、やり直す通信の失敗に含めない" do
    refute_includes DeliverWebhookJob::TRANSIENT_NETWORK_ERRORS, DeliverWebhookJob::DeadlineExceeded
    # 1 回の読み取りの時間切れは、これまでどおりやり直す。
    assert_includes DeliverWebhookJob::TRANSIENT_NETWORK_ERRORS, Timeout::Error
  end

  test "期限の内に終わる応答はこれまでどおり成功する" do
    deliver_to_local_server(status: "200 応答", deadline: 5,
                            body_bytes: 64, chunked: true, chunk_bytes: 16, chunk_delay: 0.01)

    delivery = @endpoint.webhook_deliveries.recent_first.first

    assert_equal 200, delivery.response_status
    assert_nil delivery.error_message
    assert delivery.delivered_at.present?
  end

  # --- 失敗の記録 ---
  #
  # 例外の文面をそのまま残さない。Net::HTTP は接続に失敗すると、宛先と
  # ポートを含む文面へ差し替えて送出し直す。OpenSSL の文面にも宛先が入る。
  # 記録は画面に出て、持ち出されることがある。

  test "例外を決めた区分の文面へ写す" do
    {
      DeliverWebhookJob::ResponseTooLarge.new => :response_too_large,
      DeliverWebhookJob::DeadlineExceeded.new => :deadline_exceeded,
      OpenSSL::SSL::SSLError.new("SSL_connect returned=1 errno=0 peeraddr=10.0.0.5:443") => :tls_failed,
      Net::OpenTimeout.new => :connection_timeout,
      Net::ReadTimeout.new => :connection_timeout,
      Net::WriteTimeout.new => :connection_timeout,
      Timeout::Error.new => :connection_timeout,
      SocketError.new("getaddrinfo: Name or service not known") => :resolution_failed,
      Net::HTTPBadResponse.new("wrong status line") => :invalid_response,
      Errno::ECONNREFUSED.new("connect(2) for \"10.0.0.5\" port 80") => :connection_failed,
      Errno::ECONNRESET.new => :connection_failed,
      EOFError.new("end of file reached") => :connection_failed,
      RuntimeError.new("残してはいけない値") => :unexpected
    }.each do |error, reason|
      assert_equal message_for(reason), DeliverWebhookJob.delivery_error_message(error), error.class.name
    end
  end

  test "接続できない宛先を決めた文面で記録する" do
    # 受け付けるものがいない宛先へつなぎ、接続の失敗を作る。
    address = loopback_address(3)
    @endpoint.update_column(:url, "http://hooks.internal.example/events")

    assert_raises(DeliverWebhookJob::TransientDeliveryError) { perform_to(address) }

    assert_recorded_safely(message_for(:connection_failed), address)
  end

  test "暗号化できない宛先を決めた文面で記録する" do
    address = loopback_address(4)
    @endpoint.update_column(:url, "https://hooks.internal.example/events")

    # TLS を待っている相手へ平文を返す。handshake の途中で失敗する。
    with_local_server(address, port: 443, malformed: true, greet: true) do
      assert_raises(DeliverWebhookJob::TransientDeliveryError) do
        perform_to(address, origin: "https://hooks.internal.example:443")
      end
    end

    assert_recorded_safely(message_for(:tls_failed), address)
  end

  test "解釈できない応答を決めた文面で記録する" do
    address = loopback_address(5)
    @endpoint.update_column(:url, "http://hooks.internal.example/events")

    with_local_server(address, malformed: true) { perform_to(address) }

    assert_recorded_safely(message_for(:invalid_response), address)
  end

  test "上限と期限の記録も同じ形にそろえる" do
    deliver_to_local_server(status: "200 応答", status_line_bytes: OVERSIZED_BYTES)

    assert_recorded_safely(message_for(:response_too_large), loopback_address(2))

    deliver_to_local_server(status: "200 応答", deadline: 0.5, **SLOW_RESPONSE)

    assert_recorded_safely(message_for(:deadline_exceeded), loopback_address(2))
  end

  # --- やり直し ---

  test "合計 5 回まで実行し、待ち時間はメールとそろえる" do
    assert_equal 5, DeliverWebhookJob::MAXIMUM_ATTEMPTS
    assert_equal NotificationMailDeliveryJob::RETRY_INTERVALS, DeliverWebhookJob::RETRY_INTERVALS
  end

  test "やり直す応答の範囲" do
    [ 408, 425, 429, 500, 502, 503, 504, 599 ].each do |status|
      assert_includes DeliverWebhookJob::RETRYABLE_STATUSES, status, "#{status} をやり直さない"
    end

    [ 200, 201, 204, 301, 302, 400, 401, 403, 404, 409, 410, 422, 451 ].each do |status|
      refute_includes DeliverWebhookJob::RETRYABLE_STATUSES, status, "#{status} をやり直している"
    end
  end

  test "一時的な応答ではやり直しを積み、記録も残す" do
    [ 408, 425, 429, 500, 503 ].each do |status|
      assert_difference -> { WebhookDelivery.count }, 1 do
        assert_raises(DeliverWebhookJob::TransientDeliveryError, "#{status} でやり直しへ渡していない") do
          deliver_to_local_server(status: "#{status} 応答")
        end
      end

      assert_equal status, @endpoint.webhook_deliveries.recent_first.first.response_status
    end
  end

  test "成功と恒久的な応答ではやり直さない" do
    [ 200, 204, 302, 400, 404, 422 ].each do |status|
      deliver_to_local_server(status: "#{status} 応答")

      assert_equal status, @endpoint.webhook_deliveries.recent_first.first.response_status
    end
  end

  test "通信そのものの失敗ではやり直しを積む" do
    # 受け付けるものがいない宛先へつなぎ、接続の失敗を作る。
    address = loopback_address(3)

    job = DeliverWebhookJob.new
    job.resolver = ->(_hostname, _port) { [ address ] }
    job.allowlist = Set["http://hooks.internal.example:80"]
    @endpoint.update_column(:url, "http://hooks.internal.example/events")

    assert_difference -> { WebhookDelivery.count }, 1 do
      assert_raises(DeliverWebhookJob::TransientDeliveryError) do
        job.perform(@endpoint.id, "request_submitted", { subject_id: 1 })
      end
    end

    assert @endpoint.webhook_deliveries.recent_first.first.error_message.present?
  end

  test "宛先の拒否ではやり直さない" do
    job = DeliverWebhookJob.new
    job.resolver = ->(_hostname, _port) { [ "10.0.0.1" ] }

    # やり直しの例外が出ないこと自体が契約である。
    job.perform(@endpoint.id, "request_submitted", { subject_id: 1 })

    assert_equal "destination_not_allowed", @endpoint.webhook_deliveries.recent_first.first.failure_code
  end

  test "やり直しの例外へ宛先や送信内容を入れない" do
    error = assert_raises(DeliverWebhookJob::TransientDeliveryError) do
      deliver_to_local_server(status: "503 応答", payload: { secret: "漏れてはいけない値" })
    end

    refute_includes error.message, "漏れてはいけない値"
    refute_includes error.message, "hooks.internal.example"
  end

  test "配信識別子を添え、やり直しても変わらない" do
    address = loopback_address
    @endpoint.update_column(:url, "http://hooks.internal.example/events")

    with_local_server(address) do |received|
      job = DeliverWebhookJob.new
      job.resolver = ->(_hostname, _port) { [ address ] }
      job.allowlist = Set["http://hooks.internal.example:80"]

      # 同じジョブを 2 回実行する。やり直しは同じ job_id で行われる。
      job.perform(@endpoint.id, "request_submitted", { subject_id: 1 })
      job.perform(@endpoint.id, "request_submitted", { subject_id: 1 })

      identifiers = received.call.map { |request| request.headers["x-officeweave-delivery-id"] }

      assert_equal 2, identifiers.size
      assert identifiers.all?(&:present?), "配信識別子が空になっている"
      assert_equal 1, identifiers.uniq.size, "やり直しで配信識別子が変わっている"
      assert_equal job.job_id, identifiers.first
    end
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

  private
    # 応答を決めた受信サーバーへ送り、本文として書き込めた byte 数を返す。
    #
    # やり直しへ渡ることを期待する場合は expect へ例外を渡す。
    # 送信の側で例外が出ても、受け取る側が書き込めた量は確かめられる。
    def deliver_to_local_server(status:, payload: { subject_id: 1 }, expect: nil, deadline: nil, **response)
      address = loopback_address(2)
      @endpoint.update_column(:url, "http://hooks.internal.example/events")

      with_local_server(address, status: status, **response) do |_received, written|
        job = DeliverWebhookJob.new
        job.resolver = ->(_hostname, _port) { [ address ] }
        job.allowlist = Set["http://hooks.internal.example:80"]
        job.total_deadline = deadline if deadline

        perform = -> { job.perform(@endpoint.id, "request_submitted", payload) }
        expect ? assert_raises(expect) { perform.call } : perform.call

        written.call
      end
    end

    # 宛先を差し替えず、同じ受信サーバーへもう一度送る。
    def perform_to(address, origin: "http://hooks.internal.example:80")
      job = DeliverWebhookJob.new
      job.resolver = ->(_hostname, _port) { [ address ] }
      job.allowlist = Set[origin]
      job.perform(@endpoint.id, "request_submitted", { subject_id: 1 })
    end

    def message_for(reason)
      DeliverWebhookJob::DELIVERY_ERROR_MESSAGES.fetch(reason)
    end

    # 記録が決めた文面だけで、宛先も送信内容も含まないこと。
    def assert_recorded_safely(expected, address)
      message = @endpoint.webhook_deliveries.recent_first.first.error_message

      assert_equal expected, message
      [ address, "hooks.internal.example", "/events", "80", "443",
        @endpoint.secret, "subject_id" ].each do |secret|
        refute_includes message, secret, "記録へ #{secret} が入っている"
      end
    end

    # 実行単位と開いている口の数。打ち切りのたびに残っていないかを見る。
    def process_resources
      GC.start
      descriptors = Dir["/proc/self/fd/*"]

      { threads: Thread.list.size, descriptors: descriptors.size,
        sockets: descriptors.count { |path| (File.readlink(path) rescue "").start_with?("socket:") } }
    end

    # 状態を受け取る前に上限を超えた場合の記録。
    def assert_oversized_failure
      delivery = @endpoint.webhook_deliveries.recent_first.first

      assert_nil delivery.response_status, "状態を受け取っていないのに残している"
      assert_nil delivery.delivered_at
      assert_nil delivery.failure_code
      assert_equal message_for(:response_too_large), delivery.error_message
    end
end
