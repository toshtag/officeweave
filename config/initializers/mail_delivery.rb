# メール送信の設定。
#
# 接続先は環境変数で与える。導入先ごとに送信経路が異なるため、
# 設定ファイルを書き換えずに切り替えられるようにする。
#
# 送信先が設定されていない場合は送信しない。
# 未設定のまま送信を試みると、待ち時間だけが増えて何も届かない。
Rails.application.configure do
  config.action_mailer.default_options = {
    from: ENV.fetch("MAIL_FROM", "officeweave@localhost")
  }

  # 送信のやり直しを扱うジョブ。
  # 一時的な失敗と恒久的な失敗を分けるため、既定のジョブを差し替える。
  config.action_mailer.delivery_job = "NotificationMailDeliveryJob"

  smtp_address = ENV["SMTP_ADDRESS"]

  if smtp_address.present?
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.perform_deliveries = true
    config.action_mailer.smtp_settings = {
      address: smtp_address,
      port: ENV.fetch("SMTP_PORT", 587).to_i,
      domain: ENV["SMTP_DOMAIN"].presence,
      user_name: ENV["SMTP_USER_NAME"].presence,
      password: ENV["SMTP_PASSWORD"].presence,
      authentication: ENV["SMTP_AUTHENTICATION"].presence,
      enable_starttls_auto: ENV.fetch("SMTP_ENABLE_STARTTLS", "true") == "true"
    }.compact
  elsif Rails.env.development?
    # 開発環境では送信せず、内容をファイルへ書き出す。
    config.action_mailer.delivery_method = :file
    config.action_mailer.file_settings = { location: Rails.root.join("tmp/mails") }
  elsif !Rails.env.test?
    config.action_mailer.perform_deliveries = false
  end

  # 表示する URL の組み立てに使う。
  # 受け入れる Host と同じ正本を通す。同じ環境変数へ別々の検査を持たない。
  # 運用環境の既定は、受け入れる Host と同じ localhost へ揃える。
  # 別の既定を置くと、設定しないまま起動したときに公開先が 2 つに割れる。
  host = Officeweave::Configuration::ApplicationHost.resolve(
    ENV["APPLICATION_HOST"],
    default: Rails.env.production? ? "localhost" : nil
  )

  # 公開 URL のポートは WEB_PORT から自動で決めない。
  # WEB_PORT はホストから web コンテナへ公開するポートであり、
  # 逆プロキシやポート転送の背後では、利用者が接続するポートと一致しない。
  port = Officeweave::Configuration::ApplicationPort.resolve(ENV["APPLICATION_PORT"])

  if host.present?
    options = {
      host: host,
      protocol: ENV.fetch("APPLICATION_PROTOCOL", "https")
    }
    options[:port] = port if port

    config.action_mailer.default_url_options = options
  end
end
