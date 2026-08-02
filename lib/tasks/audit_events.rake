# 監査記録を標準出力へ書き出す。
#
# 画面からの書き出しには件数の上限がある。保持期間で消える前に全件を
# 残す用途では、上限に当たると使えない。こちらは上限を持たず、
# 1 行ずつ流し込む。全体をメモリへ載せない。
#
# ホスト側で受け取る形は、バックアップの取得と同じである。
#
#   docker compose -f compose.production.yaml exec -T web \
#     bin/rails officeweave:export_audit_events > audit-events.csv
#
# 進捗は標準エラーへ出す。標準出力へ混ぜると、受け取った CSV が壊れる。
namespace :officeweave do
  desc "監査記録を CSV として標準出力へ書き出す"
  task export_audit_events: :environment do
    warn "監査記録を書き出しています"

    AuditEventCsv.new(AuditEvent.all).write($stdout)

    warn "書き出しました"
  end
end
