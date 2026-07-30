# The test environment is used exclusively to run your application's
# test suite. You never need to work with it otherwise. Remember that
# your test database is "scratch space" for the test suite and is wiped
# and recreated between test runs. Don't rely on the data there!

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # While tests run files are not watched, reloading is not necessary.
  config.enable_reloading = false

  # Eager loading loads your entire application. When running a single test locally,
  # this is usually not necessary, and can slow down your test suite. However, it's
  # recommended that you enable it in continuous integration systems to ensure eager
  # loading is working properly before deploying your code.
  config.eager_load = ENV["CI"].present?

  # Configure public file server for tests with cache-control for performance.
  config.public_file_server.headers = { "cache-control" => "public, max-age=3600" }

  # Show full error reports.
  config.consider_all_requests_local = true
  config.cache_store = :null_store

  # Render exception templates for rescuable exceptions and raise for other exceptions.
  config.action_dispatch.show_exceptions = :rescuable

  # Disable request forgery protection in test environment.
  config.action_controller.allow_forgery_protection = false

  # Store uploaded files on the local file system in a temporary directory.
  config.active_storage.service = :test

  # Tell Action Mailer not to deliver emails to the real world.
  # The :test delivery method accumulates sent emails in the
  # ActionMailer::Base.deliveries array.
  config.action_mailer.delivery_method = :test

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = { host: "example.com" }

  # Print deprecation notices to the stderr.
  config.active_support.deprecation = :stderr

  # Raises error for missing translations.
  # config.i18n.raise_on_missing_translations = true

  # Annotate rendered view with file names.
  # config.action_view.annotate_rendered_view_with_filenames = true

  # Raise error when a before_action's only/except options reference missing actions.
  config.action_controller.raise_on_missing_callback_actions = true

  # テストのジョブは実行を待たずに確かめる。
  # worker の起動を前提にすると、テストの成否が実行順に左右される。
  # Solid Queue そのものの確認は、Docker を使う統合検証で行う。
  config.active_job.queue_adapter = :test

  # Webhook 宛先の名前解決。
  #
  # 実行環境の DNS へ依存させない。IP を直接書いた宛先はそのまま返し、
  # 決まったホスト名だけを決まったアドレスへ解決する。
  # それ以外は解決できない扱いとし、外部へ問い合わせない。
  config.x.webhook_destination_resolver = lambda do |hostname, _port|
    begin
      return [ IPAddr.new(hostname).to_s ]
    rescue IPAddr::Error
      # ホスト名として扱う。
    end

    case hostname
    when "example.com", "hooks.example.com" then [ "93.184.216.34" ]
    when "localhost" then [ "::1", "127.0.0.1" ]
    when "internal.example", "hooks.internal.example" then [ "10.0.0.5" ]
    else raise WebhookDestination::Error.new(:resolution_failed)
    end
  end
end
