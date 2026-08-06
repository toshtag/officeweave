class AddOccurrenceToNotifications < ActiveRecord::Migration[8.1]
  # 通知の重複防止を、出来事の発生の単位にする。
  #
  # これまでは受け手と対象と種類だけで一意としていた。同じ申請が差し戻され、
  # 直して再提出されても、承認者には新しい未読が作られなかった。同じ利用者が
  # 複数の段を担当する場合も、2 つ目の段で作られなかった。どちらも、届いた
  # ことに気付けないまま止まる。
  #
  # 発生を表す値を足し、一意の対象へ加える。値は、同じ出来事に対して何度
  # 呼んでも同じになるものとする。時刻や乱数を入れると、ジョブのやり直しで
  # 通知が増える。
  #
  # 既にある通知には空を入れる。1 つの対象と種類につき 1 件しか無いため、
  # 空でも重ならない。過去の通知は 1 件も失われない。
  def up
    add_column :notifications, :occurrence, :string, null: false, default: ""

    add_index :notifications, %i[user_id subject_type subject_id event occurrence],
              unique: true, name: "index_notifications_on_user_and_subject_event_occurrence"
    remove_index :notifications, name: "index_notifications_on_user_and_subject_event"
  end

  def down
    # 戻す前に、発生の単位で増えた通知を落とす。戻した索引は同じ組を
    # 1 件しか許さないため、残したままでは索引を作れない。
    execute <<~SQL
      DELETE FROM notifications
       WHERE id NOT IN (
         SELECT MIN(id) FROM notifications
          GROUP BY user_id, subject_type, subject_id, event
       )
    SQL

    add_index :notifications, %i[user_id subject_type subject_id event],
              unique: true, name: "index_notifications_on_user_and_subject_event"
    remove_index :notifications, name: "index_notifications_on_user_and_subject_event_occurrence"
    remove_column :notifications, :occurrence
  end
end
