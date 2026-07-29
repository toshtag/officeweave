# 認証方式の登録。
#
# 既定の内部認証だけを登録する。
# 外部の認証基盤を使う場合は、ここへ登録を追加し、
# AUTHENTICATION_PROVIDER でその名前を指定する。
Rails.application.config.to_prepare do
  Authentication::ProviderRegistry.register(Authentication::InternalProvider)
end
