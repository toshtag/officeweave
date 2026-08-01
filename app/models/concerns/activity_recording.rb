# 最終利用時刻の記録を、要求ごとの書き込みから間引く。
#
# 認証済みの要求はすべて、セッションまたは token の最終利用時刻を更新する。
# 1 回ごとに書くと、画面を表示するだけの要求まで書き込みを伴う。
# PostgreSQL では更新のたびに行の版が増え、同じ行への更新どうしが待ち合う。
# 画面を複数開いている利用者ほど当たりやすい。
#
# 記録が遅れる向きにしか働かない。書かなかった分だけ時刻は過去のままに
# なるため、時刻を起点にする期限は早く来ることはあっても、遅く来ることは
# ない。認証が緩む向きには働かない。
module ActivityRecording
  extend ActiveSupport::Concern

  private
    def recorded_recently?(recorded_at, at, interval)
      recorded_at.present? && recorded_at > at - interval
    end
end
