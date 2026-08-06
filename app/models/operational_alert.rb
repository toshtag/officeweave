# 運用の異常を知らせた記録。
#
# 送ったかどうかを残す。残さないと、定期実行が二度動いたときに同じ内容が
# 二度届き、届いていないと思っても確かめる先が無い。
#
# 発生の単位で 1 件だけ残す。同じ異常が続いているあいだは送り直さない。
# 毎日同じ内容が届くと、通知そのものが読まれなくなる。
class OperationalAlert < ApplicationRecord
  # 同じ異常を知らせ直すまでの間隔。
  #
  # 続いている異常でも、いつかは知らせ直す必要がある。読み流したまま
  # 忘れられると、知らせない期間がそのまま放置の期間になる。
  REMINDER_INTERVAL = 7.days

  validates :occurrence, presence: true, length: { maximum: 200 }

  scope :recent_first, -> { order(sent_at: :desc, id: :desc) }

  def self.delete_expired(at: Time.current)
    expired(at: at).delete_all
  end

  # まだ知らせていない発生であれば記録し、真を返す。
  #
  # 記録の作成で判断する。先に問い合わせて確かめてから書くと、定期実行が
  # 同時に二度動いたときに両方が通る。一意の索引に判断そのものを任せる。
  def self.claim(occurrence, at: Time.current)
    create!(occurrence: occurrence, sent_at: at)
    true
  rescue ActiveRecord::RecordNotUnique
    reclaim(occurrence, at: at)
  end

  # 知らせ直す間隔を過ぎていれば、記録の時刻を進めて知らせ直す。
  #
  # 更新した件数で判断する。読んでから書くと、同時に動いた 2 つが
  # どちらも「間隔を過ぎている」と読み、二度送る。
  def self.reclaim(occurrence, at: Time.current)
    where(occurrence: occurrence)
      .where(sent_at: ...(at - REMINDER_INTERVAL))
      .update_all(sent_at: at, updated_at: at)
      .positive?
  end
  private_class_method :reclaim
end
