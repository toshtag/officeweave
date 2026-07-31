require "test_helper"
require "open3"
require "timeout"

# メール本文の公開 URL を、実際の起動で確かめる。
#
# 公開 URL は受け入れる Host と同じ設定から組み立てる。
# ホストから web コンテナへ公開する WEB_PORT は使わない。
# 逆プロキシの背後では、利用者が接続するポートと内部のポートが一致しない。
class MailUrlConfigurationTest < ActiveSupport::TestCase
  BOOT_TIMEOUT = 60

  test "設定が無い場合は受け入れる Host と同じ既定値になる" do
    status, output = boot

    assert_predicate status, :success?, output
    assert_includes output, %(MAIL_OPTIONS:{host: "localhost", protocol: "https"})
  end

  test "逆プロキシ構成では公開 URL へポートを付けない" do
    status, output = boot("APPLICATION_HOST" => "officeweave.example.com", "WEB_PORT" => "3210")

    assert_predicate status, :success?, output
    assert_includes output, %(MAIL_OPTIONS:{host: "officeweave.example.com", protocol: "https"})
  end

  test "コンテナの公開ポートを公開 URL へ流用しない" do
    status, output = boot("APPLICATION_HOST" => "officeweave.example.com", "WEB_PORT" => "3210")

    assert_predicate status, :success?, output
    assert_not_includes output, "3210"
  end

  test "非標準のポートで直接公開する場合は公開 URL へポートが入る" do
    status, output = boot(
      "APPLICATION_HOST" => "officeweave.example.com",
      "APPLICATION_PROTOCOL" => "http",
      "APPLICATION_PORT" => "3210",
      "WEB_PORT" => "3210"
    )

    assert_predicate status, :success?, output
    assert_includes output, %(MAIL_OPTIONS:{host: "officeweave.example.com", protocol: "http", port: 3210})
    assert_includes output, "URL:http://officeweave.example.com:3210/"
  end

  test "空文字の公開ポートは指定しないものとして扱う" do
    status, output = boot("APPLICATION_HOST" => "officeweave.example.com", "APPLICATION_PORT" => "")

    assert_predicate status, :success?, output
    assert_includes output, %(MAIL_OPTIONS:{host: "officeweave.example.com", protocol: "https"})
  end

  test "範囲の外の公開ポートでは起動しない" do
    assert_rejected "0"
    assert_rejected "65536"
  end

  test "前後に空白がある公開ポートでは起動しない" do
    assert_rejected " 3210"
  end

  private
    # メールの本文と同じ設定で URL を組み立てる。
    # routes 側の既定値はメールとは別に持つため、明示的に渡す。
    RESOLVE = <<~'RUBY'.freeze
      options = ActionMailer::Base.default_url_options
      puts "MAIL_OPTIONS:#{options.inspect}"
      puts "URL:#{Rails.application.routes.url_helpers.root_url(**options)}"
    RUBY

    def assert_rejected(port)
      status, output = boot("APPLICATION_HOST" => "officeweave.example.com", "APPLICATION_PORT" => port)

      assert_not_predicate status, :success?, output
      assert_not_includes output, "MAIL_OPTIONS:"
      assert_includes output, "APPLICATION_PORT"
      assert_includes output, port.inspect
    end

    # 運用環境として起動する。渡さなかった変数は子プロセスへも与えない。
    def boot(settings = {})
      environment = {
        "RAILS_ENV" => "production",
        "SECRET_KEY_BASE" => "verification-only-secret-key-base-verification-only-secret-key-base",
        "APPLICATION_HOST" => nil,
        "APPLICATION_PROTOCOL" => nil,
        "APPLICATION_PORT" => nil,
        "WEB_PORT" => nil
      }.merge(settings)

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
