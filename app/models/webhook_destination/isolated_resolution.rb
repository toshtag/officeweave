require "socket"

class WebhookDestination
  # 名前解決を子プロセスで行い、時間切れでは確実に回収する。
  #
  # getaddrinfo は C の中で止まる。thread へ逃がして join に上限を付けても、
  # 上限を過ぎた thread は止められない。呼出側は時間切れとして先へ進む一方、
  # 解決を続ける thread は process の中に残る。時間切れのたびに残るため、
  # 繰り返すと件数に比例して増える。
  #
  # そのため子プロセスへ逃がす。時間切れでは SIGKILL で落とし、回収まで
  # 見届ける。SIGKILL は捕捉も無視もできないため、C の中で止まっていても
  # 必ず終わる。thread では作れない、確実に打ち切れる境界がここにある。
  #
  # fork がある環境を前提にする。配布する構成は Linux のコンテナであり、
  # web も worker もそこで動く。無い環境では NotImplementedError で止まる。
  # 黙って thread へ戻す形にはしない。同じ欠陥が見えないまま残る。
  class IsolatedResolution
    # 子から親へ結果を渡すときの印。
    # 解決した address と、解決できなかったことを区別する。
    SUCCESS = "ok".freeze
    FAILURE = "ng".freeze

    # 子を落としてから回収を待つ上限。
    # SIGKILL の後であり、通常は待たずに終わる。ここで待ち続けないための上限とする。
    REAP_TIMEOUT = 1
    REAP_INTERVAL = 0.01

    READ_CHUNK = 4096

    class << self
      def call(hostname, port)
        reader, writer = IO.pipe
        pid = start(hostname, port, reader, writer)
        writer.close

        payload = read_within(reader, DNS_RESOLUTION_TIMEOUT)
        payload.nil? ? handle_timeout(pid) : handle_result(pid, payload)
      ensure
        reader&.close unless reader.nil? || reader.closed?
      end

      private
        # 子は解決だけを行い、結果を書いたら即座に終わる。
        #
        # exit! を使う。親から引き継いだ at_exit を走らせると、共有している
        # データベース接続などを子の側で閉じてしまう。
        def start(hostname, port, reader, writer)
          fork do
            reader.close
            write_resolution(writer, hostname, port)
            exit!(0)
          end
        end

        def write_resolution(writer, hostname, port)
          addresses = Addrinfo.getaddrinfo(hostname, port, Socket::AF_UNSPEC, Socket::SOCK_STREAM)
          writer.write([ SUCCESS, *addresses.map(&:ip_address) ].join("\n"))
        rescue StandardError
          # 失敗の内容は親へ渡さない。宛先も resolver の詳細も外へ出さない。
          writer.write(FAILURE)
        ensure
          writer.close
        end

        # 終わりまで読む。上限を過ぎた場合は nil を返す。
        def read_within(reader, timeout)
          deadline = monotonic + timeout
          payload = +""

          loop do
            remaining = deadline - monotonic
            return nil if remaining <= 0
            return nil unless reader.wait_readable(remaining)

            chunk = reader.read_nonblock(READ_CHUNK, exception: false)
            return payload if chunk.nil?
            next if chunk == :wait_readable

            payload << chunk
          end
        end

        def handle_timeout(pid)
          kill(pid)
          reclaim(pid)

          raise Error.new(:resolution_timeout)
        end

        def handle_result(pid, payload)
          reclaim(pid)

          marker, *addresses = payload.split("\n")
          raise Error.new(:resolution_failed) unless marker == SUCCESS && addresses.any?

          addresses
        end

        def kill(pid)
          Process.kill(:KILL, pid)
        rescue Errno::ESRCH
          # 既に終わっている。回収だけ行う。
        end

        # 回収し、できなかった場合は知らせる。
        #
        # 回収できないこと自体を、無期限に待たずに扱う。
        # 利用者へ返す理由は変えない。宛先も内部の詳細も外へ出さない。
        def reclaim(pid)
          return if reap(pid)

          Rails.error.report(
            ResolutionNotReclaimed.new("名前解決の子プロセスを回収できませんでした"),
            handled: true, context: { component: "webhook_resolution" }
          )
        end

        # 上限を設けて回収する。回収できた場合だけ true を返す。
        def reap(pid)
          deadline = monotonic + REAP_TIMEOUT

          loop do
            return true if Process.wait(pid, Process::WNOHANG)
            return false if monotonic >= deadline

            sleep REAP_INTERVAL
          end
        rescue Errno::ECHILD
          true
        end

        def monotonic = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    end

    # 回収できなかったことを表す。利用者へは出さない。
    class ResolutionNotReclaimed < StandardError; end
  end
end
