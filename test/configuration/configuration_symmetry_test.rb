require "test_helper"

# 開発用と配布用の構成が、片方だけ直された状態にならないようにする。
#
# 2 つの構成は、意図して別のファイルに分けてある。分けている以上、片方へ
# 足して片方へ足し忘れることが起こる。起きても、その場では何も失敗しない。
# 手元では動き、配布先だけが動かない。逆も同じである。
#
# ここに書くのは、期待値ではなく関係である。2 つの構成を互いに突き合わせて
# 導き、どちらにも一覧を持たない。変数を 1 つ増やしても、この検査は直さない。
#
# 版・イメージ・ボリュームの一致は、それぞれ次が扱う。
#   test/configuration/runtime_version_test.rb
#   test/configuration/container_name_test.rb
# 分離そのもの（project 名、公開先、値の伝播）は script/check_compose_isolation。
class ConfigurationSymmetryTest < ActiveSupport::TestCase
  DEVELOPMENT = YAML.safe_load_file(Rails.root.join("compose.yaml"), aliases: true).freeze
  PRODUCTION = YAML.safe_load_file(Rails.root.join("compose.production.yaml"), aliases: true).freeze

  APPLICATION_SERVICES = %w[web worker].freeze

  # 開発用にだけ渡すと決めた変数。
  #
  # 空にしておく。埋める場合は、なぜ配布先では要らないのかを添える。
  # 添えられないものは、配布用への足し忘れである。
  DEVELOPMENT_ONLY_VARIABLES = [].freeze

  test "開発用と配布用が同じ service を持つ" do
    development = DEVELOPMENT.fetch("services").keys.sort
    production = PRODUCTION.fetch("services").keys.sort

    assert_equal development, production,
      "service が片方にしかない（開発 #{development} / 配布 #{production}）"
  end

  test "開発用が渡す変数は、すべて配布用にも渡る" do
    # 配布用にだけある変数は正しい。送信、公開先、鍵など、手元では要らない。
    # 逆は成り立たない。手元で要るものは、配布先でも要る。
    APPLICATION_SERVICES.each do |name|
      missing = variables_of(DEVELOPMENT, name) - variables_of(PRODUCTION, name) - DEVELOPMENT_ONLY_VARIABLES

      assert_empty missing, "#{name} へ配布用が渡していない: #{missing.join(', ')}"
    end
  end

  test "web と worker が同じ変数を受け取る" do
    # 画面を出す側とジョブを実行する側で、同じコードが同じ設定を読む。
    # 片方だけへ足すと、画面では通るのに送信だけが失敗する。
    #
    # どちらの構成も YAML のアンカーで 1 か所から配っている。それを迂回して
    # 片側へ書き足したときに、ここで気づく。
    { "開発用" => DEVELOPMENT, "配布用" => PRODUCTION }.each do |label, document|
      web = variables_of(document, "web")
      worker = variables_of(document, "worker")

      assert_equal web.sort, worker.sort,
        "#{label}で食い違う（web だけ #{(web - worker).sort} / worker だけ #{(worker - web).sort}）"
    end
  end

  private
    def variables_of(document, service)
      document.dig("services", service, "environment").to_h.keys
    end
end
