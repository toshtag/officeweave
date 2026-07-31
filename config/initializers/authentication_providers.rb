# 認証方式の登録。
#
# 既定の内部認証だけを登録する。
# 外部の認証基盤を使う場合は、ここへ登録を追加し、
# AUTHENTICATION_PROVIDER でその名前を指定する。
#
# 登録の後に設定を解決し、起動前の検査とする。
# 追加する登録は、必ずこの検査より前へ書く。
# 知らない名前が指定された場合はここで例外になり、初期化が完了しない。
# web だけでなく worker、console、runner、Rake task も同じ経路を通る。
Rails.application.config.to_prepare do
  Authentication::ProviderRegistry.register(Authentication::InternalProvider)

  Authentication::ProviderRegistry.current
end
