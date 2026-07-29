# 初期利用者を用意する。
#
# 導入直後はログインできる利用者が存在しないため、最初のひとりだけをここで作る。
# 既に存在する場合は何もしない。繰り返し実行しても結果が変わらないようにする。
#
# 資格情報は環境変数で与える。開発環境に限り、値がなければ既定値を使う。
# 本番環境で値が無い場合は、利用者を作らずに知らせる。

email_address = ENV["INITIAL_USER_EMAIL"]
password = ENV["INITIAL_USER_PASSWORD"]
name = ENV.fetch("INITIAL_USER_NAME", "管理者")

if Rails.env.development?
  email_address ||= "admin@officeweave.test"
  password ||= "officeweave"
end

if email_address.blank? || password.blank?
  Rails.logger.info("初期利用者は作成していません。INITIAL_USER_EMAIL と INITIAL_USER_PASSWORD を設定してください。")
elsif User.exists?
  Rails.logger.info("利用者が既に存在するため、初期利用者は作成していません。")
else
  User.create!(name: name, email_address: email_address, password: password)
  Rails.logger.info("初期利用者 #{email_address} を作成しました。")
end
