# 申請に対して行われた操作の記録。
#
# 状態そのものは申請が持つ。ここに残すのは「誰がいつ何をしたか」で、
# 現在の状態を導き出すためのものではない。
class RequestActivity < ApplicationRecord
  ACTIONS = %w[created submitted approved returned withdrawn].freeze

  belongs_to :request
  belongs_to :actor, class_name: "User"

  # 代理で決裁した場合の、担当していた利用者。
  #
  # 経路を通した相手と実際に判断した相手が違う場合に、その違いを残す。
  # 自分が担当する決裁では持たない。
  belongs_to :on_behalf_of, class_name: "User", optional: true

  validates :action, inclusion: { in: ACTIONS }
  validates :comment, length: { maximum: 2_000 }
  belongs_to_same_organization :actor, of: :request

  scope :chronological, -> { order(:created_at, :id) }
end
