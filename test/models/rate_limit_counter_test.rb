require "test_helper"

# 試行の数え上げ。
#
# 上限の判定はこの戻り値だけで決まる。数え直しの境目と、key ごとの独立を
# ここで固定する。
class RateLimitCounterTest < ActiveSupport::TestCase
  KEY = "rate-limit:sessions:127.0.0.1".freeze

  test "同じ key を数えると 1 ずつ増える" do
    assert_equal 1, RateLimitCounter.increment(KEY, 1, expires_in: 1.minute)
    assert_equal 2, RateLimitCounter.increment(KEY, 1, expires_in: 1.minute)
    assert_equal 3, RateLimitCounter.increment(KEY, 1, expires_in: 1.minute)
  end

  test "key が違えば互いに影響しない" do
    RateLimitCounter.increment(KEY, 1, expires_in: 1.minute)

    assert_equal 1, RateLimitCounter.increment("rate-limit:sessions:10.0.0.1", 1, expires_in: 1.minute)
  end

  test "行は key ごとに 1 つだけ作る" do
    3.times { RateLimitCounter.increment(KEY, 1, expires_in: 1.minute) }

    assert_equal 1, RateLimitCounter.where(key: KEY).count
  end

  test "期限を過ぎると 1 から数え直す" do
    at = Time.current
    RateLimitCounter.increment(KEY, 1, expires_in: 1.minute, at: at)
    RateLimitCounter.increment(KEY, 1, expires_in: 1.minute, at: at)

    assert_equal 1, RateLimitCounter.increment(KEY, 1, expires_in: 1.minute, at: at + 61.seconds)
  end

  test "期限のちょうどの時刻は数え直す側に入れる" do
    at = Time.current
    RateLimitCounter.increment(KEY, 1, expires_in: 1.minute, at: at)

    assert_equal 1, RateLimitCounter.increment(KEY, 1, expires_in: 1.minute, at: at + 1.minute)
  end

  test "期限の内側では、数え直さずに期限も伸ばさない" do
    at = Time.current
    RateLimitCounter.increment(KEY, 1, expires_in: 1.minute, at: at)
    RateLimitCounter.increment(KEY, 1, expires_in: 1.minute, at: at + 30.seconds)

    # 窓の終わりは最初の 1 回で決まる。要求のたびに伸びると、送り続ける
    # 相手はいつまでも数え直しへ到達しない。
    assert_in_delta at + 1.minute, RateLimitCounter.find_by(key: KEY).expires_at, 1.second
  end

  test "期限を過ぎた行だけを後始末で消す" do
    at = Time.current
    RateLimitCounter.increment("expired", 1, expires_in: 1.minute, at: at)
    RateLimitCounter.increment("alive", 1, expires_in: 10.minutes, at: at)

    assert_equal 1, RateLimitCounter.delete_expired(at: at + 5.minutes)
    assert_equal %w[alive], RateLimitCounter.pluck(:key)
  end

  test "期限のちょうどの時刻は後始末の対象にする" do
    at = Time.current
    RateLimitCounter.increment(KEY, 1, expires_in: 1.minute, at: at)

    assert_equal 1, RateLimitCounter.delete_expired(at: at + 1.minute)
  end

  # 上限の仕組み（ActionController::RateLimiting）は store.increment だけを呼ぶ。
  # 受け渡しがその形を満たすことを、制御部を通さずに固定する。
  test "受け渡しは上限の仕組みが呼ぶ形をそのまま通す" do
    assert_equal 1, RateLimitStore.increment(KEY, 1, expires_in: 1.minute)
    assert_equal 2, RateLimitStore.increment(KEY, 1, expires_in: 1.minute)
  end
end
