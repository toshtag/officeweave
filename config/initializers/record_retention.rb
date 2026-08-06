# 保持の設定を、起動の時点で読み取る。
#
# 誤った値のまま起動させない。読み取れない値を「指定なし」として扱うと、
# 消しているつもりの組織で記録が溜まり続ける。気付くのは後になる。
#
# 監査記録の保持は config/initializers/audit_retention.rb が持つ。
# 消えたこと自体を確かめられない記録であり、扱いを分けている。
Rails.application.config.to_prepare do
  Officeweave::Configuration::NotificationRetention.days
  Officeweave::Configuration::WebhookDeliveryRetention.days
  Officeweave::Configuration::OperationalAlertRetention.days
end
