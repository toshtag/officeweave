class CreateNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_preferences do |t|
      t.references :user, null: false, foreign_key: true
      # 通知の種類。Notification::EVENTS と対応する。
      t.string :event, null: false
      t.boolean :mail_enabled, null: false, default: true

      t.timestamps
    end

    # 種類ごとに 1 件だけ持つ。
    add_index :notification_preferences, %i[user_id event], unique: true
  end
end
