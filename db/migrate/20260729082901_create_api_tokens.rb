class CreateApiTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :api_tokens do |t|
      t.references :organization, null: false, foreign_key: true
      # 権限は発行した利用者から引き継ぐ。利用者と切り離した権限を持たせない。
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      # 値そのものは保存しない。発行時に一度だけ表示する。
      t.string :token_digest, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :api_tokens, :token_digest, unique: true
  end
end
