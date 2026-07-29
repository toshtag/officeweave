class CreateResources < ActiveRecord::Migration[8.1]
  def change
    create_table :resources do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :code, null: false
      t.text :description
      # 会議室の定員など。持たない設備・備品もあるため任意とする。
      t.integer :capacity
      # 予約を受け付けるかどうか。廃棄した設備も記録は残す。
      t.boolean :reservable, null: false, default: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :resources, %i[organization_id code], unique: true
  end
end
