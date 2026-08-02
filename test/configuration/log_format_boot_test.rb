require "test_helper"

# 記録の形式の設定そのものの検査。
#
# 誤った値を行形式へ落とすと、集める仕組みが JSON を待っているのに
# 人向けの文が届き続ける。届いていないことに気付くのは、記録を
# 探したときになる。起動の時点で止める。
class LogFormatBootTest < ActiveSupport::TestCase
  include BootProcessTestHelper

  test "設定が無い場合は行形式で起動する" do
    status, output = boot(nil)

    assert_predicate status, :success?, output
    assert_includes output, "BOOTED:text"
  end

  test "json を指定した場合は起動する" do
    status, output = boot("json")

    assert_predicate status, :success?, output
    assert_includes output, "BOOTED:json"
  end

  test "知らない形式が指定された場合は起動しない" do
    status, output = boot("logfmt")

    assert_not_predicate status, :success?, output
    assert_not_includes output, "BOOTED:"
    assert_includes output, "LOG_FORMAT"
    assert_includes output, "logfmt"
  end

  private
    RESOLVE = 'puts "BOOTED:#{Officeweave::Configuration::LogFormat.current}"'

    def boot(format)
      environment = { "RAILS_ENV" => "test", "LOG_FORMAT" => format }

      boot_process([ "bin/rails", "runner", RESOLVE ], environment)
    end
end
