require "test_helper"

# Webhook 宛先の判定を固定する。
#
# 名前解決は必ず注入する。外部の DNS へ依存させると、
# 検証の結果が実行環境のネットワークで変わってしまう。
class WebhookDestinationTest < ActiveSupport::TestCase
  # 解決結果を固定する resolver。
  def resolver(*addresses)
    ->(_hostname, _port) { addresses }
  end

  def failing_resolver(reason)
    ->(_hostname, _port) { raise WebhookDestination::Error.new(reason) }
  end

  def resolve(url, resolver: resolver("203.0.113.10"), allowlist: Set.new)
    WebhookDestination.resolve!(url, resolver: resolver, allowlist: allowlist)
  end

  def assert_rejected(url, reason, **options)
    error = assert_raises(WebhookDestination::Error, "#{url} が受理された") do
      resolve(url, **options)
    end

    assert_equal reason, error.reason, "#{url} の理由が想定と違う"
    error
  end

  # --- URL の形 ---

  test "http を許可する" do
    destination = resolve("http://example.com/hooks", resolver: resolver("93.184.216.34"))

    assert_equal "example.com", destination.uri.hostname
    assert_equal 80, destination.uri.port
    assert_equal "93.184.216.34", destination.ip_address
  end

  test "https を許可する" do
    destination = resolve("https://example.com/hooks/events", resolver: resolver("93.184.216.34"))

    assert_equal 443, destination.uri.port
    assert_equal "/hooks/events", destination.uri.path
  end

  test "条件を含む URL を許可する" do
    destination = resolve("https://example.com/hooks?source=officeweave", resolver: resolver("93.184.216.34"))

    assert_equal "source=officeweave", destination.uri.query
  end

  test "絶対 URL でないものを拒否する" do
    assert_rejected("//example.com/path", :invalid_url)
    assert_rejected("example.com/path", :invalid_url)
  end

  test "http と https 以外の方式を拒否する" do
    assert_rejected("ftp://example.com/", :unsupported_scheme)
    assert_rejected("file:///etc/passwd", :unsupported_scheme)
  end

  test "ホスト名の無い URL を拒否する" do
    assert_rejected("http:///path", :missing_host)
  end

  test "資格情報を含む URL を拒否する" do
    assert_rejected("http://user:password@example.com/", :credentials_not_allowed)
  end

  test "# 以降を含む URL を拒否する" do
    assert_rejected("http://example.com/path#fragment", :fragment_not_allowed)
  end

  test "80 と 443 を許可する" do
    assert_equal 80, resolve("http://example.com:80/", resolver: resolver("93.184.216.34")).uri.port
    assert_equal 443, resolve("https://example.com:443/", resolver: resolver("93.184.216.34")).uri.port
    # 方式と番号の組み合わせは問わない。
    assert_equal 443, resolve("http://example.com:443/", resolver: resolver("93.184.216.34")).uri.port
    assert_equal 80, resolve("https://example.com:80/", resolver: resolver("93.184.216.34")).uri.port
  end

  test "80 と 443 以外のポートを拒否する" do
    assert_rejected("http://example.com:22/", :port_not_allowed)
    assert_rejected("https://example.com:8443/", :port_not_allowed)
    assert_rejected("http://example.com:8080/", :port_not_allowed)
  end

  test "IPv6 の URL を解釈する" do
    destination = resolve("http://[2001:4860:4860::8888]/", resolver: resolver("2001:4860:4860::8888"))

    assert_equal "2001:4860:4860::8888", destination.uri.hostname
  end

  test "zone identifier を含む宛先を拒否する" do
    assert_rejected("http://[fe80::1%25eth0]/", :invalid_url)
  end

  test "ホスト名を小文字にし末尾のドットを落とす" do
    allowlist = Set["http://hooks.internal.example:80"]

    # 表記が違っても同じ origin として許可リストに当たる。
    assert resolve("http://Hooks.Internal.Example./", resolver: resolver("10.0.0.5"), allowlist: allowlist)
  end

  # --- IPv4 の判定 ---

  test "外部の IPv4 を許可する" do
    assert_equal "93.184.216.34", resolve("http://example.com/", resolver: resolver("93.184.216.34")).ip_address
  end

  test "拒否する IPv4 の範囲" do
    {
      "0.0.0.1" => "未指定",
      "10.0.0.1" => "私用",
      "100.64.0.1" => "CGNAT",
      "127.0.0.1" => "ループバック",
      "169.254.169.254" => "リンクローカル",
      "172.16.0.1" => "私用",
      "192.0.0.1" => "予約済み",
      "192.0.2.1" => "文書例示",
      "192.168.0.1" => "私用",
      "198.18.0.1" => "ベンチマーク",
      "198.51.100.1" => "文書例示",
      "203.0.113.1" => "文書例示",
      "224.0.0.1" => "マルチキャスト",
      "240.0.0.1" => "予約済み"
    }.each do |address, description|
      assert_rejected("http://example.com/", :destination_not_allowed, resolver: resolver(address))
      assert true, description
    end
  end

  # --- IPv6 の判定 ---

  test "外部の IPv6 を許可する" do
    assert_equal "2001:4860:4860::8888",
                 resolve("http://example.com/", resolver: resolver("2001:4860:4860::8888")).ip_address
  end

  test "拒否する IPv6 の範囲" do
    %w[:: ::1 fc00::1 fd00::1 fe80::1 ff02::1 2001:db8::1].each do |address|
      assert_rejected("http://example.com/", :destination_not_allowed, resolver: resolver(address))
    end
  end

  test "IPv4-mapped IPv6 で判定を抜けられない" do
    %w[::ffff:127.0.0.1 ::ffff:10.0.0.1 ::ffff:169.254.169.254 ::ffff:192.168.0.1].each do |address|
      assert_rejected("http://example.com/", :destination_not_allowed, resolver: resolver(address))
    end
  end

  test "IP の特殊表記は解決後の判定で拒否される" do
    # OS の解決が 127.0.0.1 として扱うため、最終的な IP で拒否される。
    %w[2130706433 0177.0.0.1 0x7f000001].each do |host|
      assert_rejected("http://#{host}/", :destination_not_allowed, resolver: resolver("127.0.0.1"))
    end
  end

  # --- 名前解決 ---

  test "解決結果が無い宛先を拒否する" do
    assert_rejected("http://example.com/", :resolution_failed, resolver: resolver)
  end

  test "解決の失敗を拒否する" do
    assert_rejected("http://example.com/", :resolution_failed,
                    resolver: failing_resolver(:resolution_failed))
  end

  test "解決の時間切れを拒否する" do
    assert_rejected("http://example.com/", :resolution_timeout,
                    resolver: failing_resolver(:resolution_timeout))
  end

  test "解決で予期しない例外が出ても許可しない" do
    assert_rejected("http://example.com/", :resolution_failed,
                    resolver: ->(_hostname, _port) { raise SocketError, "解決できません" })
  end

  test "外部のアドレスだけなら許可する" do
    destination = resolve("http://example.com/", resolver: resolver("93.184.216.34", "2001:4860:4860::8888"))

    assert_equal "93.184.216.34", destination.ip_address
  end

  test "内部のアドレスだけなら拒否する" do
    assert_rejected("http://example.com/", :destination_not_allowed,
                    resolver: resolver("10.0.0.1", "192.168.0.1"))
  end

  test "外部と内部が混ざる解決結果を拒否する" do
    assert_rejected("http://example.com/", :destination_not_allowed,
                    resolver: resolver("93.184.216.34", "127.0.0.1"))
  end

  test "重複した解決結果を整理する" do
    destination = resolve("http://example.com/", resolver: resolver("93.184.216.34", "93.184.216.34"))

    assert_equal "93.184.216.34", destination.ip_address
  end

  # --- 許可リスト ---

  test "許可リストの既定は空" do
    assert_empty WebhookDestination.allowlist_from_environment(nil)
    assert_empty WebhookDestination.allowlist_from_environment("")
    assert_empty WebhookDestination.allowlist_from_environment("  ")
  end

  test "許可リストは origin へ正規化される" do
    allowlist = WebhookDestination.allowlist_from_environment(
      "http://hooks.internal.example, https://10.0.0.20"
    )

    assert_equal Set["http://hooks.internal.example:80", "https://10.0.0.20:443"], allowlist
  end

  test "許可リストの origin と一致する内部宛先を許可する" do
    destination = resolve("http://hooks.internal.example/events",
                          resolver: resolver("10.0.0.5"),
                          allowlist: Set["http://hooks.internal.example:80"])

    assert_equal "10.0.0.5", destination.ip_address
  end

  test "許可リストは方式とポートまで一致させる" do
    allowlist = Set["http://hooks.internal.example:80"]

    assert_rejected("https://hooks.internal.example/", :destination_not_allowed,
                    resolver: resolver("10.0.0.5"), allowlist: allowlist)
    assert_rejected("http://hooks.internal.example:443/", :destination_not_allowed,
                    resolver: resolver("10.0.0.5"), allowlist: allowlist)
  end

  test "許可リストでも URL の検査は行う" do
    allowlist = Set["http://hooks.internal.example:80"]

    assert_rejected("http://user:pass@hooks.internal.example/", :credentials_not_allowed, allowlist: allowlist)
    assert_rejected("http://hooks.internal.example:8080/", :port_not_allowed, allowlist: allowlist)
  end

  test "許可リストでも名前解決の失敗は拒否する" do
    assert_rejected("http://hooks.internal.example/", :resolution_failed,
                    resolver: failing_resolver(:resolution_failed),
                    allowlist: Set["http://hooks.internal.example:80"])
  end

  test "許可リストの不正な指定を拒否する" do
    [
      "*.internal.example",
      "https://*.internal.example",
      ".internal.example",
      "10.0.0.0/8",
      "https://internal.example/path",
      "https://internal.example:8443",
      "ftp://internal.example",
      "internal.example",
      "https://internal.example/?a=1",
      "https://internal.example/#fragment",
      "https://user:pass@internal.example"
    ].each do |entry|
      error = assert_raises(WebhookDestination::Error, "#{entry} が受理された") do
        WebhookDestination.allowlist_from_environment(entry)
      end

      assert_equal :invalid_allowlist, error.reason, entry
    end
  end

  # --- 記録に残す内容 ---

  test "理由の文言に解決した IP を含めない" do
    error = assert_rejected("http://example.com/", :destination_not_allowed,
                            resolver: resolver("169.254.169.254"))

    refute_includes error.message, "169.254"
  end

  test "知らない理由は組み立てられない" do
    assert_raises(ArgumentError) { WebhookDestination::Error.new(:something_else) }
  end
end
