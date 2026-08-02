require "test_helper"
require "socket"

# 既定の名前解決の契約。
#
# 他のテストは resolver を差し替えるため、既定の実装そのものは通らない。
# ここでは差し替えず、getaddrinfo だけを置き換えて既定の実装を動かす。
#
# 実ネットワークの DNS 待ち時間には依存させない。終わらない解決は
# 解放されるまで戻らない Queue で作り、確認のたびに必ず解放する。
class WebhookResolutionTest < ActiveSupport::TestCase
  # 時間切れの判定に使う余裕。実行環境の速さでぶれる分を吸収する。
  SLACK = 3

  teardown do
    release_pending_resolutions
    restore_getaddrinfo
  end

  test "解決した address を返す" do
    with_getaddrinfo { [ Addrinfo.ip("203.0.113.10"), Addrinfo.ip("2001:db8::10") ] }

    assert_equal [ "203.0.113.10", "2001:db8::10" ],
                 WebhookDestination::DEFAULT_RESOLVER.call("hooks.example.com", 443)
  end

  test "解決できない場合は resolution_failed になる" do
    with_getaddrinfo { raise SocketError, "getaddrinfo: Name or service not known" }

    error = assert_raises(WebhookDestination::Error) do
      WebhookDestination::DEFAULT_RESOLVER.call("missing.example.com", 443)
    end

    assert_equal :resolution_failed, error.reason
  end

  test "終わらない解決は、上限の時間で resolution_timeout になる" do
    with_hanging_getaddrinfo

    started = monotonic
    error = assert_raises(WebhookDestination::Error) do
      WebhookDestination::DEFAULT_RESOLVER.call("blocked.example.com", 443)
    end
    elapsed = monotonic - started

    assert_equal :resolution_timeout, error.reason
    assert_operator elapsed, :>=, WebhookDestination::DNS_RESOLUTION_TIMEOUT
    assert_operator elapsed, :<, WebhookDestination::DNS_RESOLUTION_TIMEOUT + SLACK
  end

  # 時間切れは、呼出側が待つのをやめただけの状態にしない。
  # 解決を行っている実行単位まで終わらせる。
  test "時間切れの後に、解決を行う実行単位が残らない" do
    with_hanging_getaddrinfo

    threads_before = Thread.list.size

    assert_raises(WebhookDestination::Error) do
      WebhookDestination::DEFAULT_RESOLVER.call("blocked.example.com", 443)
    end

    assert_equal threads_before, Thread.list.size, "時間切れの後に thread が残っている"
    assert_no_child_processes
  end

  test "時間切れを繰り返しても、実行単位が増えない" do
    with_hanging_getaddrinfo

    threads_before = Thread.list.size

    3.times do
      assert_raises(WebhookDestination::Error) do
        WebhookDestination::DEFAULT_RESOLVER.call("blocked.example.com", 443)
      end
    end

    assert_equal threads_before, Thread.list.size, "繰り返した回数だけ thread が残っている"
    assert_no_child_processes
  end

  test "利用者へ返す理由に、宛先も内部の詳細も含めない" do
    with_hanging_getaddrinfo

    error = assert_raises(WebhookDestination::Error) do
      WebhookDestination::DEFAULT_RESOLVER.call("blocked.example.com", 443)
    end

    assert_equal "resolution_timeout", error.message
  end

  private
    def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    # 未回収の子プロセスも、動いたままの子プロセスも残っていないこと。
    # 残っていれば wait は ECHILD にならず、pid か nil を返す。
    def assert_no_child_processes
      assert_raises(Errno::ECHILD, "子プロセスが残っている") do
        Process.wait(-1, Process::WNOHANG)
      end
    end

    def with_getaddrinfo(&block)
      @original_getaddrinfo ||= Addrinfo.method(:getaddrinfo)
      Addrinfo.singleton_class.define_method(:getaddrinfo) { |*| block.call }
    end

    # 解放されるまで戻らない解決。実ネットワークの待ち時間には依存しない。
    def with_hanging_getaddrinfo
      @pending = Queue.new
      pending = @pending
      with_getaddrinfo { pending.pop }
    end

    # 待ちを解放する。子プロセス側で待っている場合は親の Queue へ届かないが、
    # 親の process に残った待ちがあれば、ここで確実に解く。
    def release_pending_resolutions
      10.times { @pending&.push(nil) }
      @pending = nil
    end

    def restore_getaddrinfo
      return if @original_getaddrinfo.nil?

      original = @original_getaddrinfo
      Addrinfo.singleton_class.define_method(:getaddrinfo) { |*arguments| original.call(*arguments) }
      @original_getaddrinfo = nil
    end
end
