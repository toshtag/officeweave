class Session < ApplicationRecord
  include ActivityRecording

  # 無操作のまま放置されたログインを終わらせるまでの時間。
  IDLE_TIMEOUT = 30.minutes

  # ログインしてから、操作の有無によらず終わらせるまでの時間。
  # 活動によって延ばさない。延ばすと、使い続けている端末では期限が無いのと変わらない。
  ABSOLUTE_TIMEOUT = 8.hours

  # 最終活動時刻を書き込む間隔。
  # 無操作の判定に使う 30 分に対して十分小さくとる。
  ACTIVITY_WRITE_INTERVAL = 1.minute

  belongs_to :user

  before_validation :assign_expiration, on: :create

  class << self
    # 期限を過ぎたセッション。絶対期限と無操作期限のどちらか一方でも超えたものを含む。
    def expired(at: Time.current)
      where(expires_at: ..at).or(where(last_active_at: ..(at - IDLE_TIMEOUT)))
    end

    # まだ認証に使えるセッション。
    #
    # expired の否定を書かない。or を含む条件の否定は、片方だけを反転した
    # 条件になりやすい。境界の扱いは expired? と同じとし、境界の時刻
    # ちょうどは使えないものとする。
    def usable(at: Time.current)
      where(arel_table[:expires_at].gt(at))
        .where(arel_table[:last_active_at].gt(at - IDLE_TIMEOUT))
    end

    # 定期実行から呼ぶ。callback を持たないため一括で消す。
    def delete_expired(at: Time.current)
      expired(at: at).delete_all
    end
  end

  # 境界の時刻ちょうども期限切れとする。
  def expired?(at: Time.current)
    expires_at <= at || last_active_at <= at - IDLE_TIMEOUT
  end

  def active?(at: Time.current)
    !expired?(at: at)
  end

  # 認証へ使えたときだけ呼ぶ。期限切れや無効な利用者では呼ばない。
  #
  # 直前に記録していれば書かない。無操作の判定に使う粒度は 30 分であり、
  # 1 分より細かく記録しても判定は変わらない。
  def record_activity!(at: Time.current)
    return if recorded_recently?(last_active_at, at, ACTIVITY_WRITE_INTERVAL)

    update!(last_active_at: at)
  end

  private
    # 2 つの時刻は同じ基準から決める。Time.current を別々に呼ぶと、
    # わずかにずれた基準を持つ記録ができる。
    def assign_expiration
      now = Time.current

      self.last_active_at = now
      self.expires_at = now + ABSOLUTE_TIMEOUT
    end
end
