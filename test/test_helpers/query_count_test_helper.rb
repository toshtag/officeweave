# 処理が出した問い合わせの件数を数える。
#
# 性能の退行は、件数が入力の大きさに比例して増える形で現れる。
# 実行の速さで確かめると、実行環境の速さに左右されて間欠的に失敗する。
# 出した問い合わせの件数は環境によらないため、こちらで確かめる。
#
# 期待値へ絶対の件数を書かない。書くと、無関係な変更のたびに書き換えが要る。
# 入力の大きさを変えて 2 回数え、増えないことを確かめる形で使う。
module QueryCountTestHelper
  # 数えない問い合わせ。
  #
  # トランザクションの開始と終了、スキーマの読み込みは、処理そのものが
  # 出したものではない。キャッシュから返った問い合わせも、データベースへは
  # 届いていないため数えない。
  IGNORED_NAMES = %w[SCHEMA TRANSACTION].freeze

  def count_queries(&block)
    capture_queries(&block).size
  end

  def capture_queries
    queries = []

    subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
      next if IGNORED_NAMES.include?(payload[:name].to_s)
      next if payload[:cached]

      queries << payload[:sql]
    end

    yield

    queries
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber)
  end
end
