# 申請に対して行われた操作の記録。
#
# 状態そのものは申請が持つ。ここに残すのは「誰がいつ何をしたか」で、
# 現在の状態を導き出すためのものではない。
class RequestActivity < ApplicationRecord
  ACTIONS = %w[created submitted approved returned withdrawn].freeze

  belongs_to :request
  belongs_to :actor, class_name: "User"

  validates :action, inclusion: { in: ACTIONS }
  validates :comment, length: { maximum: 2_000 }

  scope :chronological, -> { order(:created_at, :id) }
end
