# 予定の参加者を足す。
#
# 予定に関わる利用者を指名する。参加者は、公開範囲に関わらずその予定を
# 見られる。見られないと、指名された当人が内容を確かめられない。
class CreateEventParticipants < ActiveRecord::Migration[8.1]
  def change
    create_table :event_participants do |t|
      t.references :event, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    # 同じ利用者を二重に指名しない。
    add_index :event_participants, [ :event_id, :user_id ], unique: true
    # 参照できる予定の判定で、利用者から引く。
    add_index :event_participants, [ :user_id, :event_id ]
  end
end
