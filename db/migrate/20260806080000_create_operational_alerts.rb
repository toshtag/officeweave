class CreateOperationalAlerts < ActiveRecord::Migration[8.1]
  # 運用の異常を知らせた記録。
  #
  # これまで、送ったかどうかを残していなかった。定期実行が二度動けば
  # 同じ内容が二度届き、届いていないと思っても確かめる先が無かった。
  #
  # 発生の単位で 1 件だけ残す。同じ異常が続いているあいだは送り直さない。
  # 毎日同じ内容が届くと、通知そのものが読まれなくなる。
  def change
    create_table :operational_alerts do |t|
      # 何が起きたかを表す値。異常の種類の組と、その日から作る。
      t.string :occurrence, null: false
      t.datetime :sent_at, null: false

      t.timestamps
    end

    add_index :operational_alerts, :occurrence, unique: true
    add_index :operational_alerts, :sent_at
  end
end
