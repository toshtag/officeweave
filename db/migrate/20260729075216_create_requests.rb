class CreateRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :requests do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :request_type, null: false, foreign_key: true
      t.references :applicant, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :body
      # draft は下書き、pending は承認待ち、approved は承認済み、
      # returned は差し戻し、withdrawn は取り下げ。
      t.string :status, null: false, default: "draft"
      t.datetime :submitted_at
      t.datetime :decided_at

      t.timestamps
    end

    add_index :requests, %i[organization_id status]
    add_index :requests, %i[applicant_id created_at]
  end
end
