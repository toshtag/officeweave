require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = { "cache-control" => "public, max-age=#{1.year.to_i}" }

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # 画像の変換は行わない。変換用のライブラリを実行環境へ持ち込まない。
  config.active_storage.variant_processor = :disabled

  # Assume all access to the app is happening through a SSL-terminating reverse proxy.
  # 逆プロキシで暗号化を終端する構成を前提とする。
  # 内部ネットワークだけで運用するなど、暗号化しない構成もあるため切り替えられるようにする。
  # 既定は有効とし、明示的に無効にした場合だけ平文を許す。
  config.assume_ssl = ENV.fetch("FORCE_SSL", "true") == "true"

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  config.force_ssl = ENV.fetch("FORCE_SSL", "true") == "true"

  # 起動確認だけは HTTPS への転送対象から外す。
  # コンテナ内からの確認は平文の HTTP で行うため、転送されると判定できない。
  # /health の業務向けの契約は変えない。
  config.ssl_options = { redirect: { exclude: ->(request) { request.path == "/up" } } }

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [ :request_id ]
  config.logger   = ActiveSupport::TaggedLogging.logger(STDOUT)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  # config.cache_store = :mem_cache_store

  # メールと Webhook の送信を永続化する。
  # 既定のインプロセスのキューでは、入れ替えや異常終了で未処理のジョブが消える。
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }

  # 終わったジョブは一定期間だけ残す。失敗したジョブは自動で消さない。
  config.solid_queue.preserve_finished_jobs = true
  config.solid_queue.clear_finished_jobs_after = 1.day

  # worker の稼働確認に使う。
  config.solid_queue.supervisor_pidfile = Rails.root.join("tmp/pids/solid_queue.pid")

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "example.com" }

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via bin/rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [ :id ]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # 受け入れるのは、利用者が接続する 1 つのホスト名だけとする。
  # 正規表現や任意のサブドメインは許可しない。許可を広げるほど、
  # 想定外の名前で届いた要求を、正規の要求と区別できなくなる。
  #
  # 値は起動の時点で検査する。middleware が組み上がる前に失敗させ、
  # 誤設定のまま稼働確認だけが通る状態を作らない。
  config.hosts = [
    Officeweave::Configuration::ApplicationHost.resolve(ENV["APPLICATION_HOST"], default: "localhost")
  ]

  # 稼働確認の経路も Host の検査から外さない。
  # 除外すると、その経路だけは任意の Host で到達できる。
  # コンテナ内からの確認は、要求する側が正しい Host を付ける。
end
