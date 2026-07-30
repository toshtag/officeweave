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
  def with_local_server(address, status: "204 No Content", location: nil)
    server = TCPServer.new(address, 80)
    received = []
    lock = Mutex.new

    acceptor = Thread.new do
      loop do
        socket = server.accept
        entry = read_request(socket)
        lock.synchronize { received << entry }
        socket.write(build_response(status, location))
        socket.close
      end
    rescue IOError, Errno::EBADF, Errno::EINVAL
      nil
    end

    yield -> { lock.synchronize { received.dup } }
  ensure
    acceptor&.kill
    server&.close
  end

  private
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

    def build_response(status, location)
      lines = [ "HTTP/1.1 #{status}" ]
      lines << "Location: #{location}" if location
      lines << "Content-Length: 0"
      lines << "Connection: close"

      "#{lines.join("\r\n")}\r\n\r\n"
    end
end
