# bin/verify で実行する。
#
# ここに並べた手順が、この製品の検証の全体である。
# 手元で実行できる状態を保ち、実行環境を問わず同じ結果になるようにする。
#
# 継続的インテグレーションは、この一覧を作り直さず、bin/verify をそのまま
# 呼び出す。手順が二重に管理される状態を作らない。
#
# 自動実行は範囲を分けて同時に走らせる。渡すのは範囲の名前だけとし、
# 手順そのものは持たせない。名前で渡す限り、手順を足す場所はここだけになる。
#
#   bin/verify          すべて（手元での既定）
#   bin/verify checks   書式とセキュリティ
#   bin/verify tests    テスト
#
# テストは TEST_SHARD=1/3 の形で分けて走らせられる。分け方は
# lib/tasks/test_files.rb にある。

SCOPES = %w[all checks tests].freeze

scope = ARGV.fetch(0, "all")

unless SCOPES.include?(scope)
  abort "範囲が違う: #{scope}（#{SCOPES.join("、")} のいずれか）"
end

CI.run do
  # 書式とセキュリティはデータベースへ触れない。用意すると、その分だけ待たせる。
  if scope == "checks"
    step "準備: 依存", "bin/setup --skip-database"
  else
    step "準備: 依存とデータベース", "bin/setup"
  end

  if %w[all checks].include?(scope)
    step "書式: Ruby", "bin/rubocop"

    # 取得済みの一覧をそのまま使わず、実行のたびに更新する。
    # 古い一覧で通っても、新しい指摘を見落としたことには気付けない。
    step "セキュリティ: 依存の脆弱性", "bin/bundler-audit check --update"
    step "セキュリティ: 静的解析", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
  end

  if %w[all tests].include?(scope)
    # 実ブラウザーを要する層は外す。ブラウザーは別の service として動かすため、
    # 追加の道具なしで手元で実行できる状態を保てない。
    # 外した層は、継続的インテグレーションの独立した仕事で実行する。
    step "テスト: 全件（実ブラウザーを除く）", "bin/rails test:except_browser"
    step "テスト: 初期データ", "env RAILS_ENV=test bin/rails db:seed:replant"
  end
end
