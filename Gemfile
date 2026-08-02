source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.3"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# 利用者と部門の入出力に使う。Ruby 3.4 で標準添付から外れたため明示する。
gem "csv"

# OIDC の id_token の検証に使う。
#
# 署名の検証、期限の判定、鍵の選択は、正確さと安全性が要求される領域である。
# 依存を避けるためだけに自作しない（設計原則 4）。
# 使うのは JWT.decode と JWT::JWK::Set だけとし、置き換えられる範囲に保つ。
gem "jwt", "~> 3.1"

# メールと Webhook の送信を永続化する。
# 保存先は既存の PostgreSQL とし、Redis などの常駐サービスを増やさない。
gem "solid_queue", "~> 1.5"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"
end

group :test do
  # システムテスト用。実行はブラウザーを使わない rack_test で行う。
  gem "capybara"
end
