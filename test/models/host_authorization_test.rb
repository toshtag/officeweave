require "test_helper"
require "open3"
require "timeout"

# 運用環境が受け入れる Host を、実際の起動で確かめる。
#
# 設定ファイルの文字列を読むだけでは、書き方を変えただけで通らなくなり、
# 逆に、値が実際にどう解決されたのかは分からない。
# 別のプロセスを運用環境として起動し、解決結果と終了状態を外側から見る。
class HostAuthorizationTest < ActiveSupport::TestCase
  BOOT_TIMEOUT = 60

  test "設定が無い場合は localhost だけを受け入れる" do
    status, output = boot(nil)

    assert_predicate status, :success?, output
    assert_includes output, %(HOSTS:["localhost"])
  end

  test "指定したホスト名だけを受け入れる" do
    status, output = boot("officeweave.example.com")

    assert_predicate status, :success?, output
    assert_includes output, %(HOSTS:["officeweave.example.com"])
  end

  test "稼働確認の経路を Host の検査から外さない" do
    status, output = boot("officeweave.example.com")

    assert_predicate status, :success?, output
    assert_includes output, "EXCLUDED:{}"
  end

  test "空文字が指定された場合は起動しない" do
    assert_rejected "", %(APPLICATION_HOST="")
  end

  test "スキームを含む値では起動しない" do
    assert_rejected "https://officeweave.example.com", %("https://officeweave.example.com")
  end

  test "ポートを含む値では起動しない" do
    assert_rejected "officeweave.example.com:443", %("officeweave.example.com:443")
  end

  test "IP アドレスとして成立しない値では起動しない" do
    assert_rejected "[:::]", %("[:::]")
  end

  private
    # 展開はテスト側ではなく子プロセスで行う。
    RESOLVE = <<~'RUBY'.freeze
      puts "HOSTS:#{Rails.application.config.hosts.inspect}"
      puts "EXCLUDED:#{Rails.application.config.host_authorization.inspect}"
    RUBY

    def assert_rejected(host, expected_in_message)
      status, output = boot(host)

      assert_not_predicate status, :success?, output
      assert_not_includes output, "HOSTS:"
      assert_includes output, "APPLICATION_HOST"
      assert_includes output, expected_in_message
    end

    # 運用環境として起動する。nil を渡した場合は環境変数そのものを与えない。
    def boot(host)
      environment = {
        "RAILS_ENV" => "production",
        "SECRET_KEY_BASE" => "verification-only-secret-key-base-verification-only-secret-key-base",
        "APPLICATION_HOST" => host
      }

      # シェルを介さず引数のまま渡す。設定値が語の区切りとして解釈されない。
      Open3.popen2e(environment, "bin/rails", "runner", RESOLVE, chdir: Rails.root.to_s) do |input, output, process|
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
