# 試行の数え上げ。
#
# 置き場所をデータベースにする。web の内側（キャッシュ領域）で数えると、
# 数え上げは処理系ごとに分かれる。web を 2 つに増やせば、利用者から見た
# 上限は 2 倍になる。総当たりを抑えるための上限が、動かしている台数という
# 運用の都合で変わってはならない。
#
# 記録としては残さない。期限を過ぎた行は定期実行がまとめて消す。
class RateLimitCounter < ApplicationRecord
  # 1 つの key に対する 1 回の数え上げ。
  #
  # 読んでから書くと、同時に届いた要求どうしが同じ値を読み、上限を超えて
  # 通る。1 文の INSERT ... ON CONFLICT DO UPDATE で行い、行の占有と
  # 加算をデータベース側に任せる。
  #
  # 期限は行の側に持つ。時間の窓が終わっていれば、加算ではなく 1 から
  # 数え直し、新しい期限を置く。窓の切り替えのためだけに DELETE を
  # 挟むと、その隙間に届いた要求を数え落とす。
  #
  # 時刻は呼び出す側から渡す。データベースの now() を使うと、テストで
  # 時間を進めても窓が切り替わらず、期限の振る舞いを確かめられない。
  def self.increment(key, amount = 1, expires_in:, at: Time.current)
    sql = sanitize_sql_array([ <<~SQL, key, amount, at + expires_in, at, at ])
      INSERT INTO rate_limit_counters (key, count, expires_at, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT (key) DO UPDATE SET
        count = CASE
                  WHEN rate_limit_counters.expires_at <= EXCLUDED.updated_at THEN EXCLUDED.count
                  ELSE rate_limit_counters.count + EXCLUDED.count
                END,
        expires_at = CASE
                       WHEN rate_limit_counters.expires_at <= EXCLUDED.updated_at THEN EXCLUDED.expires_at
                       ELSE rate_limit_counters.expires_at
                     END,
        updated_at = EXCLUDED.updated_at
      RETURNING count
    SQL

    connection.select_value(sql)
  end

  # 定期実行から呼ぶ。
  #
  # 期限を過ぎた行は、次の数え上げが自分で置き換える。置き換えられないまま
  # 残るのは、二度と来ない接続元や token のぶんである。放っておくと増え続ける。
  #
  # 境界の時刻ちょうどは消す側に入れる。数え上げも同じ時刻を数え直しの側に
  # 入れており、片方だけを残す側にすると、その 1 点だけ判断が食い違う。
  def self.delete_expired(at: Time.current)
    where(expires_at: ..at).delete_all
  end
end
