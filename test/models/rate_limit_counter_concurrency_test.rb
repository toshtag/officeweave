require "test_helper"

# 別々の接続から同時に数えた場合の確認。
#
# 読んでから書く形だと、同時に届いた要求どうしが同じ値を読み、上限を超えて
# 通る。それを確かめるには別々の接続から実行する必要があるため、
# このクラスだけトランザクションで囲む既定を外す。
class RateLimitCounterConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  KEY = "rate-limit:concurrency".freeze

  # 同時に走らせる接続の数と、1 接続あたりの回数。
  # 接続の数は接続の池の大きさに収める。超えると、待ちが競合の代わりになる。
  CONNECTIONS = 5
  PER_CONNECTION = 5

  # 待機には上限を持たせる。退行を CI の停止ではなく失敗として受け取る。
  COMPLETION_TIMEOUT = 30

  teardown do
    RateLimitCounter.where(key: KEY).delete_all
  end

  test "同時に数えても 1 回も落とさない" do
    counts = count_in_parallel

    # 数え落としがあれば合計が足りない。
    assert_equal CONNECTIONS * PER_CONNECTION, RateLimitCounter.find_by(key: KEY).count
    # 同じ値を 2 つの接続へ返すと、上限の判定がその回数だけ甘くなる。
    assert_equal counts.uniq.size, counts.size
    assert_equal (1..CONNECTIONS * PER_CONNECTION).to_a, counts.sort
  end

  test "同時に始めても行は 1 つしか作らない" do
    count_in_parallel

    assert_equal 1, RateLimitCounter.where(key: KEY).count
  end

  private
    # 出発をそろえる。順に始めると、先に始めた側が終わってから次が始まり、
    # 競合そのものが起きない。
    def count_in_parallel
      barrier = Concurrent::CyclicBarrier.new(CONNECTIONS)
      results = Array.new(CONNECTIONS)

      threads = CONNECTIONS.times.map do |index|
        Thread.new do
          barrier.wait
          results[index] = ActiveRecord::Base.connection_pool.with_connection do
            PER_CONNECTION.times.map { RateLimitCounter.increment(KEY, 1, expires_in: 5.minutes) }
          end
        end
      end

      threads.each { |thread| assert thread.join(COMPLETION_TIMEOUT), "接続が時間内に終わらなかった" }
      results.flatten
    end
end
