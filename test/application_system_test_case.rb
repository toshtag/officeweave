require "test_helper"

# システムテストはブラウザーを起動せず、rack_test で実行する。
#
# JavaScript なしで基本操作が完了することを設計上の要件としているため、
# ブラウザーを使わない経路がそのまま検証対象になる。
# ブラウザーを実行環境へ同梱すると、イメージの大きさと起動時間が増え、
# 検証の実行環境も利用者の環境から離れる。
#
# JavaScript を必要とする挙動が実際に現れた時点で、
# その画面に限ってブラウザーを使う実行方法を追加する。
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :rack_test
end
