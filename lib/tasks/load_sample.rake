# 負荷測定用のデータを投入する。
#
# 空のデータベースへ要求を投げても、応答の速さは分からない。測る前に、
# 測るに足る量を積む。
#
# 規模は LOAD_SAMPLE_SCALE で指定する。利用者の数であり、1 人あたり
# `LoadSample::PER_USER` 件の記録を積む。
#
#   docker compose -f compose.production.yaml exec web \
#     env LOAD_SAMPLE_SCALE=20 bin/rails officeweave:load_sample
#
# 専用の組織へ積む。既にある組織の記録には触れない。
namespace :officeweave do
  desc "負荷測定用のデータを投入する（LOAD_SAMPLE_SCALE で規模を指定する）"
  task load_sample: :environment do
    scale = Integer(ENV.fetch("LOAD_SAMPLE_SCALE", 20))

    warn "負荷測定用のデータを投入しています（規模 #{scale}）"

    result = LoadSample.new(scale: scale).install

    puts "投入しました。"
    result.each { |name, count| puts "  #{name}: #{count} 件" }
    puts
    puts "測定に使う利用者: #{LoadSample::EMAIL_ADDRESS}"
  end
end
