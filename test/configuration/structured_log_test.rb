require "test_helper"
require "stringio"
require "logger"

# 要求と送信の記録を、集める仕組みが読める形で出す。
#
# 記録の保管と回収は組織の環境にある仕組みへ委ねている。委ねる先が読むのは
# 1 行 1 件の構造化された記録であり、人向けの文ではない。
class StructuredLogTest < ActionDispatch::IntegrationTest
  setup do
    @output = StringIO.new
    @original_logger = Rails.logger
    Rails.logger = ActiveSupport::TaggedLogging.new(Logger.new(@output)).tap do |logger|
      logger.formatter = Officeweave::Logging::JsonFormatter.new
    end
  end

  teardown do
    Rails.logger = @original_logger
    ENV.delete("LOG_FORMAT")
  end

  test "要求の結果を 1 件の記録として出す" do
    ENV["LOG_FORMAT"] = "json"
    sign_in_as users(:taro)

    get audit_events_url

    event = events_named("http_request").last

    assert_equal "GET", event.fetch("method")
    assert_equal "/audit_events", event.fetch("path")
    assert_equal 200, event.fetch("status")
    assert_equal "AuditEventsController", event.fetch("controller")
    assert_equal "index", event.fetch("action")
    assert_kind_of Numeric, event.fetch("duration_ms")
  end

  test "要求の記録に、誰のどの組織の要求かを残す" do
    ENV["LOG_FORMAT"] = "json"
    sign_in_as users(:taro)

    get audit_events_url

    event = events_named("http_request").last

    assert_equal users(:taro).id, event.fetch("user_id")
    assert_equal users(:taro).organization_id, event.fetch("organization_id")
  end

  test "ログインしていない要求では、利用者の項目を持たない" do
    ENV["LOG_FORMAT"] = "json"

    get new_session_url

    event = events_named("http_request").last

    refute_includes event.keys, "user_id"
    assert_equal 200, event.fetch("status")
  end

  test "秘密情報を記録へ写さない" do
    ENV["LOG_FORMAT"] = "json"

    post session_url, params: { email_address: users(:taro).email_address, password: "password-for-tests" }

    event = events_named("http_request").last

    refute_includes @output.string, "password-for-tests"
    refute_includes event.keys, "params"
  end

  test "行形式では構造化した記録を出さない" do
    # 人が読む形式のままで要約を二重に出すと、同じことが 2 行で並ぶ。
    sign_in_as users(:taro)

    get audit_events_url

    assert_empty events_named("http_request")
  end

  test "送信の実行を 1 件の記録として出す" do
    ENV["LOG_FORMAT"] = "json"

    perform_enqueued_jobs do
      PublishScheduledAnnouncementsJob.perform_later
    end

    event = events_named("job_performed").last

    assert_equal "PublishScheduledAnnouncementsJob", event.fetch("job")
    assert_equal "default", event.fetch("queue")
    assert_kind_of Numeric, event.fetch("duration_ms")
  end

  private
    def events_named(name)
      @output.string.lines.filter_map do |line|
        parsed = JSON.parse(line) rescue nil
        parsed if parsed.is_a?(Hash) && parsed["event"] == name
      end
    end
end
