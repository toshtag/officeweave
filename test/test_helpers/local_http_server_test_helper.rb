require "socket"

# 実際のソケットで送信を確かめるための、その場限りの受信サーバー。
#
# 宛先のポートは 80 と 443 だけを許すため、高いポートでは受け取れない。
# ループバックの 80 番で待ち受け、並列実行でぶつからないよう
# プロセスごとに違うループバックのアドレスを使う。
module LocalHttpServerTestHelper
  Received = Struct.new(:request_line, :headers, :body, keyword_init: true)

  # プロセスごとに固定のループバックアドレス。
  # 127.0.0.0/8 の中から選び、末尾が 0 にならないようにする。
  def loopback_address(offset = 0)
    pid = Process.pid
    "127.#{(pid >> 8) & 0xff}.#{(pid & 0xff)}.#{((offset * 8) % 250) + 2}"
  end

  # 受信サーバーを立て、受け取った要求を集める。
  #
  # body_bytes を渡すと、その大きさの本文を返す。chunked を真にすると
  # Content-Length を付けず、同じ量を chunk に分けて返す。
  #
  # chunk_delay を渡すと、塊ごとにその秒数だけ間を空ける。
  # 1 回の読み取りは待ち時間の上限に収まるが、全体では長く続く応答を作れる。
  #
  # ブロックの第 2 引数では、本文として実際に書き込めた byte 数を読める。
  # 送信側が途中で読み取りをやめると、書き込みはそこで止まる。
  # 送った量と返そうとした量の差が、打ち切られたことの証拠になる。
  def with_local_server(address, status: "204 No Content", location: nil,
                        body_bytes: 0, chunked: false, chunk_bytes: 4096, chunk_delay: 0)
    server = TCPServer.new(address, 80)
    state = { received: [], written: 0, handled: 0 }
    lock = Mutex.new

    acceptor = Thread.new do
      loop do
        socket = server.accept
        entry = read_request(socket)
        lock.synchronize { state[:received] << entry }
        sent = write_response(socket, status, location, body_bytes, chunked, chunk_bytes, chunk_delay)
        socket.close
        lock.synchronize { state[:written] += sent; state[:handled] += 1 }
      end
    rescue IOError, Errno::EBADF, Errno::EINVAL
      nil
    end

    yield(-> { lock.synchronize { state[:received].dup } }, -> { written_bytes(state, lock) })
  ensure
    acceptor&.kill
    server&.close
  end

  private
    # 応答を書き終えるのを待ってから、本文として書き込めた量を返す。
    #
    # 送信側が読み取りをやめても、こちらが EPIPE を受け取るまでには間がある。
    # 待たずに読むと、打ち切られたのか元から短いのかを取り違える。
    def written_bytes(state, lock, timeout: 5)
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout

      until lock.synchronize { state[:handled] == state[:received].size && state[:handled].positive? }
        break if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline

        sleep 0.01
      end

      lock.synchronize { state[:written] }
    end

    def read_request(socket)
      request_line = socket.gets.to_s.strip
      headers = {}

      while (line = socket.gets)
        break if line == "\r\n" || line == "\n"

        name, value = line.split(":", 2)
        headers[name.to_s.strip.downcase] = value.to_s.strip
      end

      length = headers["content-length"].to_i
      body = length.positive? ? socket.read(length) : nil

      Received.new(request_line: request_line, headers: headers, body: body)
    end

    # 頭部を書いてから本文を流し、本文として書き込めた byte 数を返す。
    #
    # 送信側が上限で読み取りをやめると、書き込んでいる途中で接続が切れる。
    # 打ち切られたこと自体はこのサーバーの失敗ではないため、静かに終える。
    def write_response(socket, status, location, body_bytes, chunked, chunk_bytes, chunk_delay)
      socket.write(build_headers(status, location, body_bytes, chunked))
      write_body(socket, body_bytes, chunked, chunk_bytes, chunk_delay)
    rescue Errno::EPIPE, Errno::ECONNRESET
      0
    end

    # 一度に持つのは 1 塊だけとする。返す量そのものを組み立てると、
    # 上限を超える大きさを試すたびにテスト側が同じだけ抱えてしまう。
    def write_body(socket, body_bytes, chunked, chunk_bytes, chunk_delay)
      written = 0
      remaining = body_bytes

      begin
        while remaining.positive?
          size = [ chunk_bytes, remaining ].min
          payload = "a" * size
          socket.write(chunked ? "#{size.to_s(16)}\r\n#{payload}\r\n" : payload)
          remaining -= size
          written += size
          sleep chunk_delay if chunk_delay.positive? && remaining.positive?
        end

        socket.write("0\r\n\r\n") if chunked
      rescue Errno::EPIPE, Errno::ECONNRESET
        # 送信側が読み取りをやめた。ここまでに書き込めた量を返す。
      end

      written
    end

    def build_headers(status, location, body_bytes, chunked)
      lines = [ "HTTP/1.1 #{status}" ]
      lines << "Location: #{location}" if location
      lines << (chunked ? "Transfer-Encoding: chunked" : "Content-Length: #{body_bytes}")
      lines << "Connection: close"

      "#{lines.join("\r\n")}\r\n\r\n"
    end
end
