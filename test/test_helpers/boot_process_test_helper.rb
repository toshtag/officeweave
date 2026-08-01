require "open3"

# 別のプロセスを起動し、終了状態と出力を外側から見る。
#
# 既に起動しているテストプロセスの中で設定を読んでも、「起動しない」ことは
# 確かめられない。実際に起動して確かめる必要がある。
#
# 退行は終了状態と出力で受け取る。上限は行き詰まりを止めるためだけに置く。
# 上限を所要時間の判定に使うと、実行環境の速さがそのまま結果に入る。
# 実際、負荷の高い環境で 30 秒と 60 秒のどちらも超え、変更と無関係な失敗が出た。
#
# 起動しないことを確かめているテストは影響を受けない。失敗する側の
# プロセスは異常終了するため、上限へ達しない。
module BootProcessTestHelper
  BOOT_TIMEOUT = 180

  # 読み取りの単位。上限に達した場合に、そこまでの出力を残すために
  # 少しずつ読む。まとめて読むと、途中経過が手元に残らない。
  READ_SIZE = 4096

  private
    def boot_process(command, environment, timeout: BOOT_TIMEOUT)
      Open3.popen2e(environment, *command, chdir: Rails.root.to_s) do |input, output, process|
        input.close

        # 読み取りは符号化を決めずに集め、最後に一度だけ変換する。
        # 区切りが多バイト文字の途中に来ても、文字が壊れない。
        buffer = +"".b
        lock = Mutex.new
        reader = collect_output(output, buffer, lock)

        next [ process.value, text_of(buffer, lock) ] if reader.join(timeout)

        # 待ち続けるプロセスを残さない。
        Process.kill("KILL", process.pid)
        # 子が残した書き手がいると、閉じるまで読み取りが終わらない。
        output.close
        reader.join
        process.join

        flunk(timeout_message(timeout, text_of(buffer, lock)))
      end
    end

    def collect_output(output, buffer, lock)
      Thread.new do
        loop do
          chunk = output.readpartial(READ_SIZE)
          lock.synchronize { buffer << chunk }
        end
      rescue EOFError, IOError
        nil
      end
    end

    def text_of(buffer, lock)
      lock.synchronize { buffer.dup }.force_encoding(Encoding::UTF_8)
    end

    # 何秒待ったかだけでは、起動しなかったのか遅かったのかを判別できない。
    def timeout_message(timeout, captured)
      return "#{timeout} 秒以内に起動が終わらず、出力もありませんでした" if captured.empty?

      "#{timeout} 秒以内に起動が終わりませんでした。そこまでの出力:\n#{captured}"
    end
end
