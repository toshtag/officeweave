class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications do |t|
      t.references :user, null: false, foreign_key: true
      # 通知の対象となった記録。種類によって参照先が変わる。
      t.references :subject, null: false, polymorphic: true
      # 何が起きたか。文面は表示時に組み立てる。
      t.string :event, null: false
      t.datetime :read_at

      t.timestamps
    end

    # 未読を先に、新しい順で引く。
    add_index :notifications, %i[user_id created_at]

    # 同じ出来事について、同じ利用者へ二重に通知しない。
    add_index :notifications, %i[user_id subject_type subject_id event], unique: true,
              name: "index_notifications_on_user_and_subject_event"
  end
end
