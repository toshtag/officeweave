# 数え上げの置き場所。
#
# レート制限の store は、制御部の定義の時点で解決される。Rails.cache を
# そのまま渡すと、あとから差し替えても定義時のものが使われ続ける。
# 呼び出しの時点の Rails.cache へ向けるため、薄い受け渡しだけを置く。
#
# 使うのは increment だけである（ActionController::RateLimiting）。
module RateLimitStore
  def self.increment(name, amount = 1, **options)
    Rails.cache.increment(name, amount, **options)
  end
end
