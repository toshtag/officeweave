# 組織で共有する文書。
class Document < ApplicationRecord
  VISIBILITIES = %w[organization departments].freeze

  # 添付できるファイルの上限。
  # 大きなファイルを共有する用途は想定せず、規程や手順書の補助資料を想定する。
  MAX_ATTACHMENT_SIZE = 20.megabytes
  MAX_ATTACHMENT_COUNT = 10

  belongs_to :organization
  belongs_to :document_category, optional: true
  belongs_to :author, class_name: "User"

  has_many :document_departments, dependent: :destroy
  has_many :departments, through: :document_departments

  has_many_attached :attachments

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, length: { maximum: 100_000 }
  validates :visibility, inclusion: { in: VISIBILITIES }
  belongs_to_same_organization :author, :document_category
  validate :departments_required_when_limited
  validate :departments_must_be_in_same_organization
  validate :attachments_must_be_within_limits

  scope :recently_updated, -> { order(updated_at: :desc, id: :desc) }

  # 一覧に並べる列だけを選ぶ。
  #
  # 本文は最大 100,000 文字あり、一覧では表示しない。全列を返すと、
  # 表示しない本文が文書の件数だけ Rails process へ渡る。検索の条件として
  # 本文を使うことは変わらない。絞り込みはデータベースの側で終わる。
  #
  # 作成者と分類の外部キーは残す。落とすと先読みが成立せず、
  # 文書の件数だけ問い合わせが増える。
  scope :listed, -> { select(:id, :title, :document_category_id, :author_id, :updated_at) }

  # 参照できる文書。
  # 作成者は公開範囲に関わらず自分の文書を参照できる。
  scope :visible_to, ->(user) {
    in_organization = where(organization_id: user.organization_id)

    in_organization
      .where(author_id: user.id)
      .or(in_organization.where(visibility: "organization"))
      .or(in_organization.where(id: DocumentDepartment
        .where(department_id: Membership.where(user_id: user.id).select(:department_id))
        .select(:document_id)))
  }
  scope :in_category, ->(category_id) { where(document_category_id: category_id) if category_id.present? }

  # 件名と本文の部分一致で探す。
  #
  # 語の区切りを空白で判断する検索は、日本語の文章では語を切り出せない。
  # 部分一致であれば、区切りのない文章でも、英語の単語でも同じ書き方で引ける。
  # 索引は 3 文字組で作ってあるため、件数が増えても総当たりにはならない。
  scope :search, ->(query) {
    term = query.to_s.strip
    next if term.blank?

    pattern = "%#{sanitize_sql_like(term)}%"
    # 添付の名前も対象にする。探す側は、文書の題名ではなく渡された
    # ファイルの名前を覚えていることがある。
    #
    # 結合ではなく副問い合わせで引く。結合すると、名前が一致した添付の数だけ
    # 同じ文書が並ぶ。
    where(arel_table[:title].matches(pattern)
            .or(arel_table[:body].matches(pattern))
            .or(arel_table[:id].in(attached_document_ids(pattern).arel)))
  }

  # 添付の名前が一致する文書の識別子。
  #
  # 保存基盤の表を直に引く。名前は blob が持ち、attachment が文書へ結び付ける。
  def self.attached_document_ids(pattern)
    ActiveStorage::Attachment
      .where(record_type: "Document", name: "attachments")
      .where(blob_id: ActiveStorage::Blob.where(ActiveStorage::Blob.arel_table[:filename].matches(pattern))
                                         .select(:id))
      .select(:record_id)
  end

  # 作成者と管理者だけが変更できる。
  def editable_by?(user)
    author_id == user.id || user.administrator?
  end

  def limited_to_departments?
    visibility == "departments"
  end

  private
    # 受け入れる大きさと件数を明示する。
    # 制限がないと、保存領域が尽きた時点で初めて問題が分かる。
    def attachments_must_be_within_limits
      return unless attachments.attached?

      errors.add(:attachments, :too_many, count: MAX_ATTACHMENT_COUNT) if attachments.size > MAX_ATTACHMENT_COUNT

      attachments.each do |attachment|
        next if attachment.blob.byte_size <= MAX_ATTACHMENT_SIZE

        errors.add(:attachments, :too_large, filename: attachment.filename.to_s,
                                             size: MAX_ATTACHMENT_SIZE / 1.megabyte)
      end
    end

    def departments_required_when_limited
      return unless limited_to_departments?
      return if departments.any? || document_departments.any?

      errors.add(:department_ids, :blank)
    end

    def departments_must_be_in_same_organization
      return if departments.all? { |department| department.organization_id == organization_id }

      errors.add(:department_ids, :different_organization)
    end
end
