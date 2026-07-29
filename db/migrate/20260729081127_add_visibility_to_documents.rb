class AddVisibilityToDocuments < ActiveRecord::Migration[8.1]
  def change
    # organization は組織全体、departments は指定した部門に限る。
    add_column :documents, :visibility, :string, null: false, default: "organization"
  end
end
