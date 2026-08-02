require "socket"
require "zlib"
require "stringio"

# 実際のソケットで送信を確かめるための、その場限りの受信サーバー。
#
# 宛先のポートは 80 と 443 だけを許すため、高いポートでは受け取れない。
# ループバックの 80 番で待ち受け、並列実行でぶつからないよう
# プロセスごとに違うループバックのアドレスを使う。
module LocalHttpServerTestHelper
  Received = Struct.new(:request_line, :headers, :body, keyword_init: true)

  # 返す応答の指定。
  #
  # 本文の量だけでなく、ステータス行とヘッダーの量も決められるようにする。
  # 受け取る側の上限は本文だけに掛かるものではない。片方しか作れないと、
  # 上限の抜けを外から確かめられない。
  Plan = Struct.new(:status, :location, :body_bytes, :chunked, :chunk_bytes, :chunk_delay,
                    :status_line_bytes, :header_bytes, :single_header_bytes,
                    :content_encoding, :broken_encoding, :trailer, :malformed, :payload, keyword_init: true)

  DEFAULT_PLAN = {
    status: "204 No Content", location: nil, body_bytes: 0, chunked: false,
    chunk_bytes: 4096, chunk_delay: 0, status_line_bytes: 0, header_bytes: 0,
    single_header_bytes: 0, content_encoding: nil, broken_encoding: false,
    trailer: false, malformed: false, payload: nil
  }.freeze

  # プロセスごとに固定のループバックアドレス。
  # 127.0.0.0/8 の中から選び、末尾が 0 にならないようにする。
  def loopback_address(offset = 0)
    pid = Process.pid
    "127.#{(pid >> 8) & 0xff}.#{(pid & 0xff)}.#{((offset * 8) % 250) + 2}"
  end

  # 受信サーバーを立て、受け取った要求を集める。
  #
  # ブロックの第 2 引数では、応答として実際に書き込めた byte 数を読める。
  # ステータス行、ヘッダー、本文をすべて数える。送信側が途中で読み取りを
  # やめると書き込みはそこで止まる。返そうとした量との差が、
  # 打ち切られたことの証拠になる。
  def with_local_server(address, **options)
    port = options.delete(:port) || 80
    plan = Plan.new(**DEFAULT_PLAN.merge(options))
    plan.payload = plan.broken_encoding ? broken_payload : compress(plan.body_bytes) if plan.content_encoding
    server = TCPServer.new(address, port)
    state = { received: [], written: 0, handled: 0 }
    lock = Mutex.new

    acceptor = Thread.new do
      loop do
        socket = server.accept
        entry = read_request(socket)
        lock.synchronize { state[:received] << entry }
        sent = write_response(socket, plan)
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
    # 応答を書き終えるのを待ってから、書き込めた量を返す。
    #
    # 送信側が読み取りをやめても、こちらが EPIPE を受け取るまでには間がある。
    # 待たずに読むと、打ち切られたのか元から短いのかを取り違える。
    def written_bytes(state, lock, timeout: 10)
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

    # 応答を流し、書き込めた byte 数を返す。
    #
    # 送信側が上限で読み取りをやめると、書き込んでいる途中で接続が切れる。
    # 打ち切られたこと自体はこのサーバーの失敗ではないため、静かに終える。
    def write_response(socket, plan)
      written = 0
      written += write_padded(socket) { |emit| write_status_line(emit, plan) }
      written += write_padded(socket) { |emit| write_headers(emit, plan) }
      written + write_payload(socket, plan)
    rescue Errno::EPIPE, Errno::ECONNRESET, IOError
      written
    end

    # 大きさを指定された部分は、まとめて組み立てずに小分けで流す。
    # 返す量そのものを組み立てると、テスト側が同じだけ抱えてしまう。
    def write_padded(socket)
      written = 0
      emit = ->(text) { socket.write(text); written += text.bytesize }
      yield(emit)
      written
    rescue Errno::EPIPE, Errno::ECONNRESET, IOError
      written
    end

    def pad(emit, bytes, filler = "O")
      remaining = bytes
      while remaining.positive?
        size = [ 65536, remaining ].min
        emit.call(filler * size)
        remaining -= size
      end
    end

    def write_status_line(emit, plan)
      # HTTP として解釈できない列。応答の組み立てで失敗する経路を作る。
      return emit.call("NOT-HTTP ここは応答ではない\r\n\r\n") if plan.malformed

      emit.call("HTTP/1.1 #{plan.status}")
      pad(emit, plan.status_line_bytes)
      emit.call("\r\n")
    end

    def write_headers(emit, plan)
      return if plan.malformed

      emit.call("Location: #{plan.location}\r\n") if plan.location
      emit.call("Content-Encoding: #{plan.content_encoding}\r\n") if plan.content_encoding
      emit.call("Trailer: X-Checked\r\n") if plan.trailer

      if plan.single_header_bytes.positive?
        emit.call("X-Big: ")
        pad(emit, plan.single_header_bytes, "v")
        emit.call("\r\n")
      end

      (plan.header_bytes / 1024).times { |i| emit.call("X-Pad-#{i}: #{'v' * 1000}\r\n") }
      emit.call(framing_header(plan))
      emit.call("Connection: close\r\n\r\n")
    end

    def framing_header(plan)
      return "Transfer-Encoding: chunked\r\n" if plan.chunked

      "Content-Length: #{payload_size(plan)}\r\n"
    end

    def payload_size(plan)
      plan.content_encoding ? plan.payload.bytesize : plan.body_bytes
    end

    # 圧縮として解釈できない列。展開する実装なら例外になる。
    def broken_payload
      ("\x1f\x8b\x08\x00" + ("\xff" * 512)).b
    end

    def compress(bytes)
      io = StringIO.new
      Zlib::GzipWriter.wrap(io) { |writer| writer.write("a" * bytes) }
      io.string
    end

    def write_payload(socket, plan)
      return 0 if plan.malformed
      return write_compressed(socket, plan) if plan.content_encoding
      return 0 if plan.body_bytes.zero?

      write_body(socket, plan)
    end

    def write_compressed(socket, plan)
      socket.write(plan.payload)
      plan.payload.bytesize
    rescue Errno::EPIPE, Errno::ECONNRESET, IOError
      0
    end

    def write_body(socket, plan)
      written = 0
      remaining = plan.body_bytes

      begin
        while remaining.positive?
          size = [ plan.chunk_bytes, remaining ].min
          payload = "a" * size
          socket.write(plan.chunked ? "#{size.to_s(16)}\r\n#{payload}\r\n" : payload)
          remaining -= size
          written += size
          sleep plan.chunk_delay if plan.chunk_delay.positive? && remaining.positive?
        end

        socket.write(plan.trailer ? "0\r\nX-Checked: #{'v' * 32}\r\n\r\n" : "0\r\n\r\n") if plan.chunked
      rescue Errno::EPIPE, Errno::ECONNRESET, IOError
        # 送信側が読み取りをやめた。ここまでに書き込めた量を返す。
      end

      written
    end
end
