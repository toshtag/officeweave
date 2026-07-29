class CreateWebhookEndpoints < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_endpoints do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :name, null: false
      t.string :url, null: false
      # 送信内容の署名に使う。受け取る側が改ざんを検出できるようにする。
      t.string :secret, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
  end
end
