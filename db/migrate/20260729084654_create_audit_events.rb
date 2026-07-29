class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :organization, null: false, foreign_key: true
      # 操作した利用者。ログイン失敗など、特定できない場合は空にする。
      t.references :actor, foreign_key: { to_table: :users }
      t.string :action, null: false
      # 対象の記録。種類によって参照先が変わる。
      t.string :target_type
      t.bigint :target_id
      # 対象を後から識別するための補足。記録そのものが消えても内容が残る。
      t.jsonb :details, null: false, default: {}
      t.string :ip_address

      t.timestamps
    end

    add_index :audit_events, %i[organization_id created_at]
    add_index :audit_events, %i[organization_id action]
    add_index :audit_events, %i[target_type target_id]
  end
end
