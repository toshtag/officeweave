# bin/verify で実行する。
#
# ここに並べた手順が、この製品の検証の全体である。
# 手元で実行できる状態を保ち、実行環境を問わず同じ結果になるようにする。
#
# 継続的インテグレーションを導入する際は、この一覧を作り直さず、
# bin/verify をそのまま呼び出す。手順が二重に管理される状態を作らない。

CI.run do
  step "準備: 依存とデータベース", "bin/setup"

  step "書式: Ruby", "bin/rubocop"

  # 取得済みの一覧をそのまま使わず、実行のたびに更新する。
  # 古い一覧で通っても、新しい指摘を見落としたことには気付けない。
  step "セキュリティ: 依存の脆弱性", "bin/bundler-audit check --update"
  step "セキュリティ: 静的解析", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"

  # 実ブラウザーを要する層は外す。ブラウザーは別の service として動かすため、
  # 追加の道具なしで手元で実行できる状態を保てない。
  # 外した層は、継続的インテグレーションの独立した仕事で実行する。
  step "テスト: 全件（実ブラウザーを除く）", "bin/rails test:except_browser"
  step "テスト: 初期データ", "env RAILS_ENV=test bin/rails db:seed:replant"
end
