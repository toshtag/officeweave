# お知らせを読んだ記録。
class AnnouncementRead < ApplicationRecord
  belongs_to :announcement
  belongs_to :user

  validates :user_id, uniqueness: { scope: :announcement_id }
end
