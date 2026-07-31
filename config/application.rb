require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
# require "action_cable/engine"
require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# 環境設定の評価より前に読み込む。
# config/environments/production.rb から使うため、autoload の順序へ依存させない。
require_relative "../lib/officeweave/configuration/application_host"
require_relative "../lib/officeweave/configuration/application_port"

module Officeweave
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # configuration は環境設定より前に明示的に読み込む。
    # autoload の対象に残すと、同じ定数を二重に定義することになる。
    config.autoload_lib(ignore: %w[assets tasks officeweave/configuration])

    # 利用者向け画面は日本語と英語に対応する。
    # 既定は日本語とし、対応していない言語が指定された場合も既定へ落とす。
    config.i18n.available_locales = %i[ja en]
    config.i18n.default_locale = :ja
    config.i18n.fallbacks = [ :ja ]

    config.time_zone = "Asia/Tokyo"

    # スキーマ定義を SQL 形式で保持する。
    # 期間の重なりを除外する制約は Ruby 形式では表現できず、
    # 取りこぼすと、複製した環境で重複が防げなくなる。
    config.active_record.schema_format = :sql

    # 保存基盤が用意する経路を作らない。
    #
    # 標準の経路は署名付きの ID を知っている相手へそのまま配信する。
    # ログインの有無も、文書の参照範囲も見ないため、
    # 添付に対して文書と同じ制限をかけられない。
    # 範囲を後から狭めても、発行済みの URL は期限まで有効なままになる。
    #
    # 添付は DocumentAttachmentsController だけから返す。
    # ここは環境ごとに変える設定ではないため、全環境へ一度だけ書く。
    config.active_storage.draw_routes = false

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
