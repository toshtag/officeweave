class CreateDocumentCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :document_categories do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code, null: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :document_categories, %i[organization_id code], unique: true
  end
end
