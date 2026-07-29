# 組織内の部門。上位部門を持てる。
class Department < ApplicationRecord
  belongs_to :organization
  belongs_to :parent, class_name: "Department", optional: true

  has_many :children, class_name: "Department", foreign_key: :parent_id, dependent: :restrict_with_error
  has_many :memberships, dependent: :destroy
  has_many :announcement_departments, dependent: :destroy
  has_many :event_departments, dependent: :destroy
  has_many :users, through: :memberships

  normalizes :code, with: ->(value) { value.strip.downcase }

  validates :name, presence: true, length: { maximum: 100 }
  validates :code, presence: true, length: { maximum: 50 },
                   format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ },
                   uniqueness: { scope: :organization_id }
  validate :parent_must_be_in_same_organization
  validate :parent_must_not_form_a_cycle

  scope :ordered, -> { order(:position, :name) }
  scope :roots, -> { where(parent_id: nil) }

  # 上位から自身までの並び。画面での位置づけを示すために使う。
  def ancestors
    result = []
    node = parent

    while node && result.exclude?(node)
      result.unshift(node)
      node = node.parent
    end

    result
  end

  def display_path
    (ancestors + [ self ]).map(&:name).join(" / ")
  end

  private
    def parent_must_be_in_same_organization
      return if parent.nil? || parent.organization_id == organization_id

      errors.add(:parent, :different_organization)
    end

    # 自身を子孫に持つ部門を上位に指定すると、階層をたどる処理が終わらなくなる。
    def parent_must_not_form_a_cycle
      return if parent.nil?

      node = parent

      while node
        if node == self
          errors.add(:parent, :cyclic)
          return
        end

        node = node.parent
      end
    end
end
