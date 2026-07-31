require "test_helper"
require "open3"
require "timeout"

module Authentication
  # 起動そのものの検査。
  #
  # 既に起動しているテストプロセスの中で current を呼んでも、
  # 「起動しない」ことは確かめられない。別のプロセスを実際に起動し、
  # 終了状態と出力を外側から見る。
  class ProviderBootTest < ActiveSupport::TestCase
    BOOT_TIMEOUT = 30

    test "設定が無い場合は内部認証で起動する" do
      status, output = boot(nil)

      assert_predicate status, :success?, output
      assert_includes output, "BOOTED:internal"
    end

    test "内部認証を明示した場合は起動する" do
      status, output = boot("internal")

      assert_predicate status, :success?, output
      assert_includes output, "BOOTED:internal"
    end

    test "知らない名前が指定された場合は起動しない" do
      status, output = boot("does-not-exist")

      assert_not_predicate status, :success?, output
      assert_not_includes output, "BOOTED:"
      assert_includes output, "AUTHENTICATION_PROVIDER"
      assert_includes output, "does-not-exist"
      assert_includes output, "internal"
      assert_not_includes output, "内部認証を使用します"
    end

    test "空文字が指定された場合は起動しない" do
      status, output = boot("")

      assert_not_predicate status, :success?, output
      assert_not_includes output, "BOOTED:"
      assert_includes output, %(AUTHENTICATION_PROVIDER="")
    end

    private
      # 認証方式を指定して Rails を起動する。
      # nil を渡した場合は、環境変数そのものを子プロセスへ渡さない。
      def boot(provider)
        environment = { "RAILS_ENV" => "test", "AUTHENTICATION_PROVIDER" => provider }
        script = 'puts "BOOTED:#{Authentication::ProviderRegistry.current.name_key}"'

        # シェルを介さず引数のまま渡す。設定値が語の区切りとして解釈されない。
        Open3.popen2e(environment, "bin/rails", "runner", script, chdir: Rails.root.to_s) do |input, output, process|
          input.close

          begin
            captured = Timeout.timeout(BOOT_TIMEOUT) { output.read }
            [ process.value, captured ]
          rescue Timeout::Error
            # 待ち続けるプロセスを残さない。
            Process.kill("KILL", process.pid)
            process.join
            flunk("#{BOOT_TIMEOUT} 秒以内に起動が終わりませんでした")
          end
        end
      end
  end
end
