class AddUnreadIndexToNotifications < ActiveRecord::Migration[8.1]
  def change
    # 未読の件数は、認証済みのすべての画面で 1 回ずつ数える。
    #
    # 既存の user_id の索引では、その利用者の通知を既読も含めて読み、
    # そのあと read_at IS NULL で落とすことになる。既読の通知は消えないため、
    # 落とす分は使い続けるかぎり増える。
    #
    # 未読だけを持つ索引にすると、走査する量が未読の件数で決まる。
    # 既読になった通知は索引から外れるため、大きさも未読の分にとどまる。
    add_index :notifications, :user_id, where: "read_at IS NULL",
              name: "index_notifications_on_unread_user_id"
  end
end
