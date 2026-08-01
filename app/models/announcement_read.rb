# お知らせを読んだ記録。
class AnnouncementRead < ApplicationRecord
  belongs_to :announcement
  belongs_to :user

  validates :user_id, uniqueness: { scope: :announcement_id }
  belongs_to_same_organization :user, of: :announcement
end
