# 監査記録の参照と書き出し。
#
# 記録は管理者だけが参照できる。誰が何をしたかは、
# 組織の運用を預かる立場でなければ必要にならない。
class AuditEventsController < ApplicationController
  before_action :require_administrator

  # 一度に表示する件数。すべてを一度に返すと、蓄積した後に開けなくなる。
  PER_PAGE = 50

  # 画面から一度に書き出せる件数。
  #
  # 上限を超えた場合は、切り詰めずに拒否する。足りない CSV を渡された側は、
  # それが全件かどうかを判断できない。全件が必要な場合はコマンドから書き出す。
  EXPORT_LIMIT = 50_000

  def index
    # 記録が消える設定になっていることは、一覧からは読み取れない。
    # 過去の記録を探したときに初めて気付く状態にしない。
    @retention_days = Officeweave::Configuration::AuditRetention.days
    @action_name = params[:audit_action]
    @actor_id = params[:actor_id]

    @page = Pagination.new(filtered_scope.recent_first.includes(:actor),
                           page: params[:page], per_page: PER_PAGE)
    @audit_events = @page.records
    @total_count = @page.total_count
    @actors = current_organization.users.ordered
  end

  def export
    scope = filtered_scope
    count = scope.count

    if count > EXPORT_LIMIT
      return redirect_to audit_events_path(audit_action: params[:audit_action], actor_id: params[:actor_id]),
                         alert: t("audit_events.export.too_many", limit: EXPORT_LIMIT, count: count)
    end

    content = AuditEventCsv.new(scope).export

    # 持ち出したこと自体を記録へ残す。件数を添えないと、後から範囲を確かめられない。
    #
    # 記録は書き出しの後に残す。先に残すと、その記録が同じ書き出しへ入り、
    # 添えた件数とファイルの行数が食い違う。
    record_audit_event("audit_events_exported", details: {
      count: count, action: params[:audit_action].presence, actor_id: params[:actor_id].presence
    }.compact)

    send_data content,
              filename: "audit-events-#{Date.current.iso8601}.csv",
              type: "text/csv; charset=utf-8"
  end

  private
    def filtered_scope
      current_organization.audit_events
                          .with_action(params[:audit_action])
                          .by_actor(params[:actor_id])
    end
end
