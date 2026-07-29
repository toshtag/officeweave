# 重要な操作の記録。
#
# 記録は書き足すだけとし、更新も削除もしない。
# 後から書き換えられる記録は、監査の用途に使えない。
class AuditEvent < ApplicationRecord
  ACTIONS = %w[
    signed_in
    sign_in_failed
    signed_out
    user_created
    user_updated
    user_deactivated
    user_activated
    department_created
    department_updated
    department_deleted
    membership_created
    membership_deleted
    request_approved
    request_returned
    api_token_issued
    api_token_revoked
    webhook_endpoint_created
    webhook_endpoint_deleted
    users_imported
    users_exported
  ].freeze

  belongs_to :organization
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :target, polymorphic: true, optional: true

  validates :action, inclusion: { in: ACTIONS }

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :with_action, ->(action) { where(action: action) if action.in?(ACTIONS) }
  scope :by_actor, ->(actor_id) { where(actor_id: actor_id) if actor_id.present? }

  # 記録を書き換えさせない。
  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }

  def self.record(organization:, action:, actor: nil, target: nil, details: {}, ip_address: nil)
    return nil if organization.nil?

    create!(
      organization: organization,
      actor: actor,
      action: action,
      target: target,
      details: details,
      ip_address: ip_address
    )
  end
end
