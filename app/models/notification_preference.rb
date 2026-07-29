# 通知の種類ごとの配信設定。
#
# 記録がない種類は、メールを送る扱いとする。
# 全員分の記録を先に作らず、変更した利用者のぶんだけを持つ。
class NotificationPreference < ApplicationRecord
  belongs_to :user

  validates :event, inclusion: { in: Notification::EVENTS },
                    uniqueness: { scope: :user_id }
end
