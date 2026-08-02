# 監査記録の参照。
#
# 記録は管理者だけが参照できる。誰が何をしたかは、
# 組織の運用を預かる立場でなければ必要にならない。
class AuditEventsController < ApplicationController
  before_action :require_administrator

  # 一度に表示する件数。すべてを一度に返すと、蓄積した後に開けなくなる。
  PER_PAGE = 50

  def index
    # 記録が消える設定になっていることは、一覧からは読み取れない。
    # 過去の記録を探したときに初めて気付く状態にしない。
    @retention_days = Officeweave::Configuration::AuditRetention.days
    @action_name = params[:audit_action]
    @actor_id = params[:actor_id]
    @page = [ params[:page].to_i, 1 ].max

    scope = current_organization.audit_events
                                .with_action(@action_name)
                                .by_actor(@actor_id)
                                .recent_first
                                .includes(:actor)

    @total_count = scope.count
    @audit_events = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE)
    @actors = current_organization.users.ordered
  end
end
