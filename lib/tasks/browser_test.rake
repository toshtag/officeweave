# 実ブラウザーでのテストの実行範囲。
#
# ブラウザーは別の service として動かす。用意されていない環境では実行できない。
# 一括検証（bin/verify）は、追加の道具なしで手元で実行できる状態を保つため、
# ブラウザーを要する層を外して走らせる。
#
# 外していることを黙って済ませない。除いた範囲は継続的インテグレーションの
# 独立した仕事で必ず実行する。
require_relative "test_files"

namespace :test do
  desc "実ブラウザーで主要な流れを確かめる（compose.browser.yaml を重ねて起動する）"
  task :browser do
    Rails::TestUnit::Runner.run_from_rake("test", [ "test/browser" ])
  end

  desc "実ブラウザーを要する層を除く全件（TEST_SHARD=1/3 で分けて走らせる）"
  task :except_browser do
    # 分けずに走らせる場合は Rails が持つ除外の仕組みを使う。試験の一覧を
    # ここへ書き写すと、層を足したときに片方だけ古くなる。
    if ENV["TEST_SHARD"].to_s.empty?
      ENV["DEFAULT_TEST_EXCLUDE"] = Officeweave::TestFiles::EXCLUDED

      Rails::TestUnit::Runner.run_from_rake("test")
    else
      Rails::TestUnit::Runner.run_from_rake("test", Officeweave::TestFiles.parse(ENV["TEST_SHARD"]))
    end
  end
end
