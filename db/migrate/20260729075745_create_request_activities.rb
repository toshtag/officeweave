class CreateRequestActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :request_activities do |t|
      t.references :request, null: false, foreign_key: true
      # 操作した利用者。無効化された利用者の記録も残す。
      t.references :actor, null: false, foreign_key: { to_table: :users }
      # created, submitted, approved, returned, withdrawn のいずれか。
      t.string :action, null: false
      t.text :comment

      t.timestamps
    end

    # 申請ごとに時系列で引く。
    add_index :request_activities, %i[request_id created_at]
  end
end
