class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :organization, null: false, foreign_key: true
      # 分類は後から付けられるようにする。分類が決まらない文書も置ける。
      t.references :document_category, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :body

      t.timestamps
    end

    add_index :documents, %i[organization_id updated_at]
  end
end
