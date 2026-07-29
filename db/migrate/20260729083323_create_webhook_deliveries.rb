class CreateWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :webhook_deliveries do |t|
      t.references :webhook_endpoint, null: false, foreign_key: true
      t.string :event, null: false
      # 送信の結果。運用時に届いているかを確認できるようにする。
      t.integer :response_status
      t.string :error_message
      t.datetime :delivered_at

      t.timestamps
    end

    add_index :webhook_deliveries, %i[webhook_endpoint_id created_at]
  end
end
