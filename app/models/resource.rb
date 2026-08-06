# 会議室や備品など、共同で使うもの。
#
# 使えなくなったものは削除せず、予約を受け付けない状態にする。
# 削除すると、過去の予約から何を使ったのかをたどれなくなる。
class Resource < ApplicationRecord
  belongs_to :organization
  has_many :reservations, dependent: :restrict_with_error

  include OrganizationScopedCode

  validates :name, presence: true, length: { maximum: 100 }
  validates :description, length: { maximum: 2_000 }
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  # 選択欄の絞り込みに使う。名前と識別子の部分一致とする。
  # 語の区切りを空白で判断する検索は、日本語の名称では語を切り出せない。
  # 利用者の検索（User.search）と同じ考え方である。
  scope :search, ->(query) {
    term = query.to_s.strip
    next if term.blank?

    pattern = "%#{sanitize_sql_like(term)}%"
    where(arel_table[:name].matches(pattern).or(arel_table[:code].matches(pattern)))
  }

  scope :ordered, -> { order(:position, :name) }
  scope :reservable, -> { where(reservable: true) }
end
