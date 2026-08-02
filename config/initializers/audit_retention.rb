# 監査記録の保持期間の検査。
#
# 起動の時点で値を確かめる。誤った値のまま起動させると、気付くのは
# 定期実行が失敗したときか、消えたはずの記録を探したときになる。
#
# web だけでなく worker、console、runner、Rake task も同じ経路を通る。
# 記録を消すのは worker であり、web だけの検査では足りない。
Rails.application.config.to_prepare do
  Officeweave::Configuration::AuditRetention.days
end
