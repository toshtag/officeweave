class AddDeactivatedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    # 退職や異動で利用を止める場合、記録を消さずに無効化する。
    # 削除すると、過去の申請や監査の記録から利用者をたどれなくなる。
    add_column :users, :deactivated_at, :datetime
    add_index :users, :deactivated_at
  end
end
