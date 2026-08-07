require "test_helper"

# 初回の起動を、1 度の実行で終えられること。
#
# 移行を web の起動処理の中で行うと、準備の途中は応答が始まらない。稼働確認は
# それを「応えない」としか見られず、移行が長引いた分だけ失敗が積み上がって
# unhealthy になる。web を待つ側は、そこで起動を諦める。
#
# 実測では、準備に 180 秒かかる状態で `up -d` が 1 を返した。待つ側の回数を
# 増やす直し方は、長引く回を隠すだけで、境界を先へずらすことにしかならない。
#
# 準備を一度きりの実行として切り出し、待つ側はその完了を待つ。完了を待つ依存
# には打ち切りが無い。
class FirstBootTest < ActiveSupport::TestCase
  PRODUCTION = YAML.safe_load_file(Rails.root.join("compose.production.yaml"), aliases: true).freeze
  SERVICES = PRODUCTION.fetch("services").freeze
  ENTRYPOINT = Rails.root.join("bin/docker-entrypoint").read.freeze

  # 準備を受け持つ実行。
  PREPARE = "prepare".freeze

  test "準備が、一度きりの実行として分かれている" do
    assert_includes SERVICES.keys, PREPARE, "準備を切り出す"
    assert_includes SERVICES.fetch(PREPARE).fetch("command").to_s, "db:prepare"
  end

  test "準備は、データベースの稼働を待つ" do
    assert_equal "service_healthy", SERVICES.fetch(PREPARE).dig("depends_on", "db", "condition")
  end

  test "準備は、稼働確認を持たない" do
    # 一度きりの実行であり、終わったあとに稼働しているものが無い。
    assert_nil SERVICES.fetch(PREPARE)["healthcheck"]
  end

  test "web と worker は、準備の完了を待つ" do
    %w[web worker].each do |name|
      assert_equal "service_completed_successfully",
                   SERVICES.fetch(name).dig("depends_on", PREPARE, "condition"),
                   "#{name} が準備の完了を待っていない"
    end
  end

  test "worker は、web の稼働確認を待たない" do
    # worker に要るのは移行が済んでいることであり、web が応えていることでは
    # ない。web を待たせると、準備が長引いた回だけ worker が起動しない。
    assert_nil SERVICES.fetch("worker").dig("depends_on", "web")
  end

  test "web の起動処理では、準備を行わない" do
    # 行うと、応答を始めるまでの時間がその分だけ延びる。
    assert_includes ENTRYPOINT, "DATABASE_PREPARED_ELSEWHERE"
    assert_equal "1", SERVICES.fetch("web").fetch("environment").fetch("DATABASE_PREPARED_ELSEWHERE")
  end

  test "準備を行う実行では、起動処理の分岐を通さない" do
    assert_equal "0", SERVICES.fetch(PREPARE).fetch("environment").fetch("DATABASE_PREPARED_ELSEWHERE")
  end

  test "起動処理は、準備を別が行う場合だけ飛ばす" do
    # 既定では行う。開発用の構成には準備の実行が無い。
    assert_match(/DATABASE_PREPARED_ELSEWHERE:-0/, ENTRYPOINT)
    assert_not_includes YAML.safe_load_file(Rails.root.join("compose.yaml"), aliases: true)
                            .fetch("services").keys, PREPARE
  end

  test "待つ側の回数で長引きを吸収していない" do
    # 回数を増やす直し方は、長引く回を隠すだけである。境界を先へずらしても、
    # その先で同じことが起きる。
    web = SERVICES.fetch("web").fetch("healthcheck")

    assert_operator web.fetch("retries"), :<=, 30, "回数で吸収しない"
    assert_operator duration(web.fetch("start_period")), :<=, 60, "猶予で吸収しない"
  end

  test "見ている service が 1 つ以上ある" do
    assert_operator SERVICES.size, :>=, 4
  end

  private
    def duration(value) = value.to_s.sub(/s\z/, "").to_i
end
