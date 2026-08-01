# 組織内の部門。上位部門を持てる。
class Department < ApplicationRecord
  belongs_to :organization
  belongs_to :parent, class_name: "Department", optional: true

  has_many :children, class_name: "Department", foreign_key: :parent_id, dependent: :restrict_with_error
  has_many :memberships, dependent: :destroy
  has_many :announcement_departments, dependent: :destroy
  has_many :event_departments, dependent: :destroy
  has_many :document_departments, dependent: :destroy
  has_many :approvable_request_types, class_name: "RequestType", foreign_key: :approver_department_id,
           dependent: :restrict_with_error, inverse_of: :approver_department
  has_many :users, through: :memberships

  normalizes :code, with: ->(value) { value.strip.downcase }

  validates :name, presence: true, length: { maximum: 100 }
  validates :code, presence: true, length: { maximum: 50 },
                   format: { with: /\A[a-z0-9][a-z0-9_-]*\z/ },
                   uniqueness: { scope: :organization_id }
  belongs_to_same_organization :parent
  validate :parent_must_not_form_a_cycle

  scope :ordered, -> { order(:position, :name) }
  scope :roots, -> { where(parent_id: nil) }

  # 複数の部門の階層を、1 回の問い合わせで組み立てられるようにする。
  #
  # 関連を 1 段ずつたどると、件数と階層の深さの積だけ問い合わせが出る。
  # includes(:parent) は 1 段目しか先読みしないため、2 段目より上はそのまま
  # 問い合わせになる。一覧を並べる場所では必ずここを通す。
  #
  # 読むのは対象と同じ組織の部門だけとする。上位が同じ組織にあることは
  # belongs_to_same_organization :parent が保証しているため、たどるのに
  # 必要な記録はこれでそろう。
  #
  # 記録そのものへ並びを持たせる。呼び出し側が別の対応表を持ち回すと、
  # display_path を呼ぶ場所ごとに渡し忘れが起きる。
  def self.with_ancestors(departments)
    records = departments.to_a
    return records if records.empty?

    index = where(organization_id: records.map(&:organization_id).uniq).index_by(&:id)
    records.each { |record| record.ancestors = trace_ancestors(record) { |node| index[node.parent_id] } }
    records
  end

  # 上位を順にたどる。たどり方だけを外から与える。
  # 同じ部門を 2 度たどらない。循環している記録でも終わる。
  def self.trace_ancestors(start)
    result = []
    node = yield(start)

    while node && result.exclude?(node)
      result.unshift(node)
      node = yield(node)
    end

    result
  end

  # with_ancestors が読み込んだ並びを渡す。
  attr_writer :ancestors

  # 上位から自身までの並び。画面での位置づけを示すために使う。
  #
  # 読み込み済みの並びがあればそれを使う。無ければ関連をたどるため、
  # 階層の深さだけ問い合わせが出る。1 件だけを表示する場所ではそれでよい。
  def ancestors
    @ancestors ||= self.class.trace_ancestors(self, &:parent)
  end

  def display_path
    (ancestors + [ self ]).map(&:name).join(" / ")
  end

  private
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
