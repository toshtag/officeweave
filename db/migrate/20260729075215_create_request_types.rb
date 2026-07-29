class CreateRequestTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :request_types do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code, null: false
      t.text :description
      # 承認を担当する部門。未指定の場合は管理者が承認する。
      t.references :approver_department, foreign_key: { to_table: :departments }
      # 新しい申請を受け付けるかどうか。過去の申請の記録は残す。
      t.boolean :active, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :request_types, %i[organization_id code], unique: true
  end
end
