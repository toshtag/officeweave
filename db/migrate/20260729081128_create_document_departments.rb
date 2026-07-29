class CreateDocumentDepartments < ActiveRecord::Migration[8.1]
  def change
    create_table :document_departments do |t|
      t.references :document, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true

      t.timestamps
    end

    add_index :document_departments, %i[document_id department_id], unique: true,
              name: "index_document_departments_on_pair"
  end
end
