# お知らせと、その公開先の部門の結びつき。
class AnnouncementDepartment < ApplicationRecord
  belongs_to :announcement
  belongs_to :department

  validates :department_id, uniqueness: { scope: :announcement_id }
  belongs_to_same_organization :department, of: :announcement
end
