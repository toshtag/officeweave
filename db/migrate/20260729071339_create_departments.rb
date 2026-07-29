class CreateDepartments < ActiveRecord::Migration[8.1]
  def change
    create_table :departments do |t|
      t.references :organization, null: false, foreign_key: true
      # 上位部門。最上位は null になる。
      t.references :parent, foreign_key: { to_table: :departments }
      t.string :name, null: false
      t.string :code, null: false
      # 画面に並べる順序。同じ値の場合は名称順とする。
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    # 識別子は組織の中で一意とする。組織をまたいだ重複は許す。
    add_index :departments, %i[organization_id code], unique: true
  end
end
