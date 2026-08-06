# 数え上げの受け渡し。
#
# レート制限の store は、制御部の定義の時点で解決される。数え上げの実体を
# ここへ直接書かず、呼び出しの時点で RateLimitCounter へ向ける。
#
# 使うのは increment だけである（ActionController::RateLimiting）。
module RateLimitStore
  def self.increment(name, amount = 1, expires_in:, **)
    RateLimitCounter.increment(name, amount, expires_in: expires_in)
  end
end
