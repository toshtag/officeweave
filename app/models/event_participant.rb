# 予定の参加者。
#
# 指名された利用者は、公開範囲に関わらずその予定を見られる。
# 出欠の返答は扱わない。指名されたことだけを記録する。
class EventParticipant < ApplicationRecord
  belongs_to :event
  belongs_to :user

  validates :user_id, uniqueness: { scope: :event_id }
  validate :user_must_not_be_owner
  validate :user_must_be_active
  belongs_to_same_organization :user, of: :event

  private
    # 所有者は指名しなくても見られる。並べると、外せない参加者ができる。
    def user_must_not_be_owner
      return if event.nil? || user_id.nil? || user_id != event.owner_id

      errors.add(:user, :event_owner)
    end

    def user_must_be_active
      return if user.nil? || user.active?

      errors.add(:user, :inactive)
    end
end
