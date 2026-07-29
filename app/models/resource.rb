# 会議室や備品など、共同で使うもの。
#
# 使えなくなったものは削除せず、予約を受け付けない状態にする。
# 削除すると、過去の予約から何を使ったのかをたどれなくなる。
class Resource < ApplicationRecord
  belongs_to :organization

  normalizes :code, with: ->(value) { value.strip.downcase }

  validates :name, presence: true, length: { maximum: 100 }
  validates :code, presence: true, length: { maximum: 50 },
                   format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ },
                   uniqueness: { scope: :organization_id }
  validates :description, length: { maximum: 2_000 }
  validates :capacity, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  scope :ordered, -> { order(:position, :name) }
  scope :reservable, -> { where(reservable: true) }
end
