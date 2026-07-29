# 予定と、その公開先の部門の結びつき。
class EventDepartment < ApplicationRecord
  belongs_to :event
  belongs_to :department

  validates :department_id, uniqueness: { scope: :event_id }
end
