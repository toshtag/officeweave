# 初期利用者を用意する。
#
# 導入直後はログインできる利用者が存在しないため、最初のひとりだけをここで作る。
# 既に存在する場合は何もしない。繰り返し実行しても結果が変わらないようにする。
#
# 資格情報は環境変数で与える。既定値は用意しない。
# 手順書に載る値をそのまま使える状態にすると、そのまま運用へ残る。
# 値が無い場合は、推測せずに利用者を作らずに知らせる。
#
# 与えられた値が最低要件を満たすかどうかは User の検証が決める。
# 満たさない場合は作成に失敗し、db:seed も失敗として終わる。

# 導入単位となる組織。既にある場合はそのまま使う。
organization = Organization.find_or_create_by!(code: ENV.fetch("ORGANIZATION_CODE", "default")) do |record|
  record.name = ENV.fetch("ORGANIZATION_NAME", "OfficeWeave")
end

email_address = ENV["INITIAL_USER_EMAIL"]
password = ENV["INITIAL_USER_PASSWORD"]
# Compose は未設定の変数を空文字で渡す。表示名だけは空欄を未設定と同じに扱う。
# 資格情報とは違い、推測して困る値ではない。
name = ENV["INITIAL_USER_NAME"].presence || "管理者"

if email_address.blank? || password.blank?
  # 既定値を廃したことで、設定し忘れは初回導入で必ず通る道になった。
  # ログの行き先は環境で違うため、実行した人へそのまま返す。
  puts "初期利用者は作成していません。"
  puts "INITIAL_USER_EMAIL と INITIAL_USER_PASSWORD を設定してから、もう一度実行してください。"
  puts "パスワードは #{Authentication::PasswordPolicy::MINIMUM_LENGTH} 文字以上にします。"
elsif User.exists?
  puts "利用者が既に存在するため、初期利用者は作成していません。"
else
  User.create!(
    organization: organization,
    name: name,
    email_address: email_address,
    password: password,
    # 最初のひとりは、他の利用者を作れる必要がある。
    role: :administrator
  )
  puts "初期利用者 #{email_address} を作成しました。"
end
