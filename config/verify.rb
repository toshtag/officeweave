# bin/verify で実行する。
#
# ここに並べた手順が、この製品の検証の全体である。
# 手元で実行できる状態を保ち、実行環境を問わず同じ結果になるようにする。
#
# 継続的インテグレーションを導入する際は、この一覧を作り直さず、
# bin/verify をそのまま呼び出す。手順が二重に管理される状態を作らない。

CI.run do
  step "準備: 依存とデータベース", "bin/setup --skip-server"

  step "書式: Ruby", "bin/rubocop"

  step "セキュリティ: 依存の脆弱性", "bin/bundler-audit"
  step "セキュリティ: 配信スクリプトの脆弱性", "bin/importmap audit"
  step "セキュリティ: 静的解析", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  step "テスト: 全件", "bin/rails test:all"
  step "テスト: 初期データ", "env RAILS_ENV=test bin/rails db:seed:replant"
end
