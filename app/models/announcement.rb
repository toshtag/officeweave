# 組織内へ知らせる内容。
#
# 公開範囲は「組織全体」と「指定した部門」の 2 種類とする。
# 個人宛の連絡は、この機能では扱わない。
class Announcement < ApplicationRecord
  VISIBILITIES = %w[organization departments].freeze

  belongs_to :organization
  belongs_to :author, class_name: "User"

  has_many :announcement_departments, dependent: :destroy
  has_many :notifications, as: :subject, dependent: :destroy
  has_many :departments, through: :announcement_departments
  has_many :announcement_reads, dependent: :destroy
  has_many :readers, through: :announcement_reads, source: :user

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, presence: true, length: { maximum: 10_000 }
  validates :visibility, inclusion: { in: VISIBILITIES }
  belongs_to_same_organization :author
  validate :departments_required_when_limited
  validate :departments_must_be_in_same_organization

  scope :published, -> { where.not(published_at: nil).where(published_at: ..Time.current) }
  # 公開日時を先に設定したもの。公開済みにも下書きにも入らない。
  scope :scheduled, -> { where(published_at: Time.current...) }
  # 公開日時が来ていて、まだ知らせていないもの。
  scope :awaiting_publication_notice, -> { published.where(notified_at: nil) }
  scope :recent_first, -> { order(published_at: :desc, created_at: :desc) }

  # 題名と本文の部分一致で引く。
  #
  # 語の区切りを空白で判断する検索は、日本語の文章では語を切り出せない。
  # 文書（Document.search）と同じ書き方でそろえる。
  scope :search, ->(query) {
    term = query.to_s.strip
    next if term.blank?

    pattern = "%#{sanitize_sql_like(term)}%"
    where(arel_table[:title].matches(pattern).or(arel_table[:body].matches(pattern)))
  }

  # 利用者が読める公開済みのお知らせ。
  # 公開範囲が部門指定の場合、その利用者の所属部門と重なるものだけを返す。
  scope :visible_to, ->(user) {
    published
      .where(organization_id: user.organization_id)
      .where(
        arel_table[:visibility].eq("organization").or(
          arel_table[:id].in(
            AnnouncementDepartment
              .where(department_id: Membership.where(user_id: user.id).select(:department_id))
              .select(:announcement_id).arel
          )
        )
      )
  }

  # まだ読まれていないお知らせ。
  scope :unread_for, ->(user) {
    where.not(id: AnnouncementRead.where(user_id: user.id).select(:announcement_id))
  }

  # 読んだ記録を残す。同じ利用者が何度開いても 1 件にとどめる。
  # 記録の有無だけを扱い、読み直した日時では上書きしない。
  def mark_as_read_by(user)
    announcement_reads.create!(user: user, read_at: Time.current)
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    nil
  end

  def read_by?(user)
    announcement_reads.exists?(user_id: user.id)
  end

  # 公開範囲に入る利用者。
  def recipients
    return organization.users.active if visibility == "organization"

    organization.users.active.where(id: Membership.where(department_id: department_ids).select(:user_id))
  end

  def published?
    published_at.present? && published_at <= Time.current
  end

  def limited_to_departments?
    visibility == "departments"
  end

  def scheduled?
    published_at.present? && published_at > Time.current
  end

  # 公開の知らせを 1 回だけ送る。
  #
  # 送ったことを記録しないと、更新のたびに送り直すことになる。記録の確定と
  # 送るかどうかの判定を、同じ占有の中で行う。定期実行と画面からの更新が
  # 同時に走っても、送るのは先に確定した側だけになる。
  #
  # 送信そのものは占有の外で行う。占有したまま外部を待つと、送信の遅れが
  # そのまま他の操作の待ち時間になる。
  def notify_publication
    claimed = with_lock do
      next false unless published? && notified_at.nil?

      update!(notified_at: Time.current)
      true
    end

    return false unless claimed

    Notification.deliver_to_all(
      users: recipients.where.not(id: author_id),
      subject: self,
      event: "announcement_published"
    )
    Notification.publish(organization: organization, subject: self, event: "announcement_published")

    true
  end

  private
    def departments_required_when_limited
      return unless limited_to_departments?
      return if departments.any? || announcement_departments.any?

      errors.add(:department_ids, :blank)
    end

    def departments_must_be_in_same_organization
      return if departments.all? { |department| department.organization_id == organization_id }

      errors.add(:department_ids, :different_organization)
    end
end
