require "test_helper"
require "yaml"

# 変更を出すたびに走らせるものの予算。
#
# 検証は放っておくと増える。1 つ足すときの理由はいつも正当であり、増えた
# 合計を見る機会が無い。気付くのは、結果を待たずにマージする習慣がついた
# あとである。そうなると、増やした検査そのものが働かなくなる。
#
# 増やすことは禁じない。黙って増えることだけを防ぐ。予算へ触れる差分は
# レビューに出る。そこで置き場所を 1 度考える機会が生まれる。
#
# テストの件数は予算に入れない。増えてよいものであり、増えた分は分割で
# 吸収する。ここで縛ると、退行に気付ける範囲が減る。
#
# 所要時間でも測らない。実行環境の速さがそのまま結果に入り、変更と無関係な
# 失敗が出る。数えるのは構造だけとする。
class VerificationBudgetTest < ActiveSupport::TestCase
  PULL_REQUEST = Rails.root.join(".github/workflows/verify.yml").freeze
  VERIFY = Rails.root.join("config/verify.rb").freeze

  # 上限は 2026-08-03 の実測に基づく。
  #
  #   実行環境を組み立てる仕事   約 66 秒
  #   組み立てない仕事        約 24 秒
  #
  # 案内は区分ごとに変える。数字だけでは、どちらへ動かすべきかが伝わらない。
  BUDGET = {
    "変更を出すたびに走る仕事" => {
      limit: 5,
      # 同時に走らせる数が増えると、ソースの取得で取り合いが起きる。5 つで
      # 1 秒から 73 秒までぶれた実測がある。数そのものにも待ち時間が乗る。
      guidance: "main へ入ったあとで足りないかを確かめる（operations.yml）。" \
                "そこへ置けない場合だけ、この予算を動かす。"
    },
    "実行環境を組み立てる仕事" => {
      limit: 3,
      # 組み立ては 1 仕事あたり 30 秒を超える。分けるほど総量は増える。
      guidance: "その仕事はデータベースへ触れるか。触れないなら、" \
                "書式とセキュリティと同じく組み立てずに走らせられる。"
    },
    "変更を出すたびに走る検査" => {
      limit: 5,
      # 手元の一括検証がそのまま走る。ここが増えると、分けても全体が伸びる。
      guidance: "毎回必要か、依存を更新したときだけでよいかを分ける。" \
                "毎回でなくてよいものは operations.yml へ置く。"
    }
  }.freeze

  BUDGET.each_key do |name|
    test "#{name}が予算に収まる" do
      limit = BUDGET.dig(name, :limit)
      actual = measured.fetch(name)

      assert_operator actual, :<=, limit,
        "#{name}が #{actual} になった（予算 #{limit}）。\n#{BUDGET.dig(name, :guidance)}"
    end
  end

  # 予算の側だけを残して数えるのをやめると、上限が働かなくなる。
  test "予算に挙げた区分をすべて数えている" do
    assert_equal BUDGET.keys.sort, measured.keys.sort
  end

  private
    def measured
      @measured ||= {
        "変更を出すたびに走る仕事" => runs.sum { |_, count| count },
        "実行環境を組み立てる仕事" => runs.sum { |job, count| built?(job) ? count : 0 },
        "変更を出すたびに走る検査" => checks.size
      }
    end

    # 分けて走らせる仕事は、その数だけ実行される。
    def runs
      @runs ||= YAML.safe_load_file(PULL_REQUEST, aliases: true)["jobs"].values
                    .to_h { |job| [ job, [ job.dig("strategy", "matrix", "include").to_a.size, 1 ].max ] }
    end

    def built?(job)
      job["steps"].to_a.any? { |step| step["uses"].to_s.include?("build-push-action") }
    end

    # 準備は範囲によって書き分けている。数えるのは検査だけとする。
    def checks
      VERIFY.read.scan(/^\s*step "([^"]+)"/).flatten.reject { |title| title.start_with?("準備") }
    end
end
