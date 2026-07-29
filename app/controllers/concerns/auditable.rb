# 重要な操作を記録へ残す。
#
# 記録する場所を controller に限る。
# 模型側で自動的に残すと、取り込みや初期データの投入まで記録され、
# 誰の操作なのかが分からない記録が混ざる。
module Auditable
  extend ActiveSupport::Concern

  private
    def record_audit_event(action, target: nil, details: {}, organization: nil, actor: :current)
      AuditEvent.record(
        organization: organization || current_organization,
        actor: actor == :current ? Current.user : actor,
        action: action,
        target: target,
        details: details,
        ip_address: request.remote_ip
      )
    end
end
