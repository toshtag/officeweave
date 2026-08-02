# 部品表を標準出力へ書き出す。
#
# 何を取り込んで配布しているのかを、外から読める形で出す。
# ホスト側で受け取る形は、バックアップの取得と同じである。
#
#   docker compose exec -T web bin/rails officeweave:sbom > officeweave-sbom.json
#
# 進捗は標準エラーへ出す。標準出力へ混ぜると、受け取った JSON が壊れる。
namespace :officeweave do
  desc "部品表（CycloneDX 形式）を標準出力へ書き出す"
  task sbom: :environment do
    warn "部品表を組み立てています"

    puts Sbom.new.to_json

    warn "書き出しました"
  end
end
