require "test_helper"

class Officeweave::Configuration::ApplicationHostTest < ActiveSupport::TestCase
  test "環境変数そのものが無い場合は既定値を返す" do
    assert_equal "localhost", resolve(nil, default: "localhost")
    assert_nil resolve(nil, default: nil)
  end

  test "ホスト名を加工せずそのまま返す" do
    [ "localhost", "officeweave.example.com", "portal.internal", "OfficeWeave.Example.COM",
      "xn--eckwd4c7c.example", "192.0.2.10", "[2001:db8::10]", "[::1]" ].each do |host|
      assert_equal host, resolve(host)
    end
  end

  test "IP アドレスとして成立しない IPv6 を拒否する" do
    assert_invalid "[:]"
    assert_invalid "[:::]"
    assert_invalid "[1....:2]"
    assert_invalid "[1:2:3:4:5:6:7:8:9]"
    assert_invalid "[gggg::1]"
    assert_invalid "[]"
    assert_invalid "[2001:db8::10"
    assert_invalid "2001:db8::10]"
  end

  test "IP アドレスとして成立しない IPv4 を拒否する" do
    assert_invalid "999.999.999.999"
    assert_invalid "192.0.2.999"
    assert_invalid "1.2.3"
    assert_invalid "1.2.3.4.5"
    assert_invalid "1.2.3."
  end

  test "IPv6 のゾーン識別子を拒否する" do
    assert_invalid "[fe80::1%eth0]"
    assert_invalid "[fe80::1%25eth0]"
    assert_invalid "[2001:db8::1%en0]"
  end

  test "ゾーン識別子を取り除いて受理しない" do
    error = assert_raises(Officeweave::Configuration::ApplicationHost::InvalidApplicationHost) do
      resolve("[fe80::1%eth0]")
    end

    assert_includes error.message, %("[fe80::1%eth0]")
    assert_includes error.message, "ゾーン識別子"
  end

  test "ゾーン識別子の無い IPv6 は認める" do
    [ "[fe80::1]", "[::ffff:127.0.0.1]", "[::ffff:192.0.2.10]" ].each do |host|
      assert_equal host, resolve(host)
    end
  end

  test "範囲の指定を 1 つのホストとして扱わない" do
    assert_invalid "[2001:db8::/32]"
    assert_invalid "192.0.2.0/24"
  end

  test "括弧のない IPv6 を拒否する" do
    assert_invalid "2001:db8::10"
  end

  test "明示した空文字は既定値へ落とさず拒否する" do
    assert_invalid ""
  end

  test "空白だけの値を拒否する" do
    assert_invalid " "
    assert_invalid "\t"
  end

  test "前後に空白がある値を取り除かずに拒否する" do
    assert_invalid " officeweave.example.com"
    assert_invalid "officeweave.example.com "
  end

  test "制御文字を含む値を拒否する" do
    assert_invalid "officeweave.example.com\n"
    assert_invalid "officeweave.example.com\r\nX-Injected: 1"
  end

  test "スキームを含む値を拒否する" do
    assert_invalid "https://officeweave.example.com"
    assert_invalid "http://officeweave.example.com"
  end

  test "経路を含む値を拒否する" do
    assert_invalid "officeweave.example.com/"
    assert_invalid "officeweave.example.com/path"
  end

  test "クエリとフラグメントを含む値を拒否する" do
    assert_invalid "officeweave.example.com?query=1"
    assert_invalid "officeweave.example.com#fragment"
  end

  test "ポートを含む値を拒否する" do
    assert_invalid "officeweave.example.com:443"
    assert_invalid "localhost:3210"
  end

  test "利用者情報を含む値を拒否する" do
    assert_invalid "user@officeweave.example.com"
  end

  test "ワイルドカードと複数ホストを拒否する" do
    assert_invalid "*.example.com"
    assert_invalid ".example.com"
    assert_invalid "officeweave.example.com,other.example.com"
  end

  test "DNS 名として成立しない値を拒否する" do
    assert_invalid "officeweave..example.com"
    assert_invalid "-officeweave.example.com"
    assert_invalid "officeweave-.example.com"
    assert_invalid "#{'a' * 64}.example.com"
    assert_invalid "#{Array.new(5, 'a' * 60).join('.')}.example.com"
  end

  test "拒否の理由には環境変数名と指定値だけを載せる" do
    error = assert_raises(Officeweave::Configuration::ApplicationHost::InvalidApplicationHost) do
      resolve("https://officeweave.example.com")
    end

    assert_includes error.message, "APPLICATION_HOST"
    assert_includes error.message, %("https://officeweave.example.com")
    assert_includes error.message, "ポート"
  end

  private
    def resolve(raw, default: "localhost")
      Officeweave::Configuration::ApplicationHost.resolve(raw, default: default)
    end

    def assert_invalid(raw)
      assert_raises(Officeweave::Configuration::ApplicationHost::InvalidApplicationHost, raw.inspect) do
        resolve(raw)
      end
    end
end
