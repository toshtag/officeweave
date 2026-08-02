require "test_helper"
require "stringio"
require "logger"

# 記録を 1 行 1 件の JSON として出す形式。
#
# 記録を集める仕組みは、1 行を 1 件として読む。1 件が複数行にまたがると、
# 例外の記録のような長いものだけが別々の件として集まる。
class Officeweave::Logging::JsonFormatterTest < ActiveSupport::TestCase
  test "1 件を 1 行の JSON として出す" do
    logger.info("起動しました")

    assert_equal 1, output.string.lines.size
    assert_equal "起動しました", parse.fetch("message")
  end

  test "時刻と水準を項目として持つ" do
    logger.warn("接続できません")

    line = parse

    assert_equal "WARN", line.fetch("level")
    # 読み手の地域によらない形にする。集める側で並べ替えられる必要がある。
    assert_match(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z\z/, line.fetch("time"))
  end

  test "改行を含む記録も 1 行に収める" do
    logger.error("失敗しました\n原因: 接続できません")

    assert_equal 1, output.string.lines.size
    assert_equal "失敗しました\n原因: 接続できません", parse.fetch("message")
  end

  test "組み立てた項目はそのまま項目として出す" do
    logger.info(event: "http_request", status: 200, path: "/documents")

    line = parse

    assert_equal "http_request", line.fetch("event")
    assert_equal 200, line.fetch("status")
    assert_equal "/documents", line.fetch("path")
    # 項目として出したものを、文へ混ぜ直さない。
    refute_includes line.keys, "message"
  end

  test "要求の識別子を項目として出す" do
    logger.tagged("abc-123") { logger.info("受け付けました") }

    line = parse

    assert_equal "abc-123", line.fetch("request_id")
    # 接頭辞としては付けない。付けると、集める側が文から切り出すことになる。
    assert_equal "受け付けました", line.fetch("message")
  end

  test "識別子が無ければ、その項目を持たない" do
    logger.info("受け付けました")

    refute_includes parse.keys, "request_id"
  end

  test "入れ子の識別子は、外側から順に並べる" do
    logger.tagged("abc-123") { logger.tagged("job-9") { logger.info("実行しました") } }

    line = parse

    assert_equal "abc-123", line.fetch("request_id")
    assert_equal [ "job-9" ], line.fetch("tags")
  end

  private
    def output
      @output ||= StringIO.new
    end

    def logger
      @logger ||= ActiveSupport::TaggedLogging.new(Logger.new(output)).tap do |logger|
        logger.formatter = Officeweave::Logging::JsonFormatter.new
      end
    end

    def parse
      JSON.parse(output.string.lines.last)
    end
end
