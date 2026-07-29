class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email_address, null: false
      t.string :password_digest, null: false
      # 表示言語の設定。未設定の場合は要求ごとに判定する。
      t.string :locale

      t.timestamps
    end

    # 大文字小文字を正規化して保存するため、単純な一意索引で足りる。
    add_index :users, :email_address, unique: true
  end
end
