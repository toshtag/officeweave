# 稼働の異常を知らせる宛先の検査。
#
# 起動の時点で値を確かめる。誤った宛先のまま起動させると、知らせようとした
# ときに送信が失敗する。異常が起きたときに、その知らせも届かない。
#
# 送るのは worker である。web だけの検査では足りないため to_prepare へ置く。
Rails.application.config.to_prepare do
  Officeweave::Configuration::OperationsEmail.current
end
