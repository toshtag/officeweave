# 実ブラウザーでのテストの実行範囲。
#
# ブラウザーは別の service として動かす。用意されていない環境では実行できない。
# 一括検証（bin/verify）は、追加の道具なしで手元で実行できる状態を保つため、
# ブラウザーを要する層を外して走らせる。
#
# 外していることを黙って済ませない。除いた範囲は継続的インテグレーションの
# 独立した仕事で必ず実行する。
namespace :test do
  desc "実ブラウザーで主要な流れを確かめる（compose.browser.yaml を重ねて起動する）"
  task :browser do
    Rails::TestUnit::Runner.run_from_rake("test", [ "test/browser" ])
  end

  desc "実ブラウザーを要する層を除く全件"
  task :except_browser do
    # Rails が持つ除外の仕組みを使う。試験の一覧をここへ書き写すと、
    # 層を足したときに片方だけ古くなる。
    ENV["DEFAULT_TEST_EXCLUDE"] = "test/{dummy,fixtures,browser}/**/*_test.rb"

    Rails::TestUnit::Runner.run_from_rake("test")
  end
end
