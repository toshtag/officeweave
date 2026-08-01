# 初期利用者を用意する。
#
# 判定と作成は InitialUser が持つ。ここでは環境変数の読み出しと、
# 実行した人への知らせだけを行う。ログの行き先は環境で違うため、
# 標準出力へそのまま返す。

email_address = ENV["INITIAL_USER_EMAIL"]

result = InitialUser.install(
  organization_code: ENV.fetch("ORGANIZATION_CODE", "default"),
  organization_name: ENV.fetch("ORGANIZATION_NAME", "OfficeWeave"),
  email_address: email_address,
  password: ENV["INITIAL_USER_PASSWORD"],
  name: ENV["INITIAL_USER_NAME"]
)

case result
when :missing_credentials
  # 既定値を廃したことで、設定し忘れは初回導入で必ず通る道になった。
  puts "初期利用者は作成していません。"
  puts "INITIAL_USER_EMAIL と INITIAL_USER_PASSWORD を設定してから、もう一度実行してください。"
  puts "パスワードは #{Authentication::PasswordPolicy::MINIMUM_LENGTH} 文字以上にします。"
when :already_present
  puts "利用者が既に存在するため、初期利用者は作成していません。"
when :created
  puts "初期利用者 #{email_address} を作成しました。"
end
