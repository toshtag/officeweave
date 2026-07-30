class AddFailureCodeToWebhookDeliveries < ActiveRecord::Migration[8.1]
  def change
    # 宛先の検査で拒否した理由。通信そのものの誤りは error_message へ残す。
    # 文言ではなく符号で持ち、表示のときに翻訳する。
    add_column :webhook_deliveries, :failure_code, :string
  end
end
