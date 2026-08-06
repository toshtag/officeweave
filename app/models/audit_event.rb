# 重要な操作の記録。
#
# 記録は書き足すだけとし、更新はしない。
# 後から書き換えられる記録は、監査の用途に使えない。
#
# 削除の経路は 1 つだけとする。保持期間より古い記録を、定期実行が
# まとめて消す。個々の記録を選んで消す経路は持たない。持つと、
# 都合の悪い 1 件だけを取り除ける状態になる。
class AuditEvent < ApplicationRecord
  ACTIONS = %w[
    signed_in
    sign_in_failed
    signed_out
    user_created
    user_updated
    user_deactivated
    password_changed
    password_reset_requested
    password_reset_completed
    sessions_revoked
    user_activated
    department_created
    department_updated
    department_deleted
    membership_created
    membership_deleted
    approval_delegation_created
    approval_delegation_deleted
    request_approved
    request_returned
    request_type_created
    request_type_updated
    api_token_issued
    api_token_revoked
    webhook_endpoint_created
    webhook_endpoint_updated
    webhook_endpoint_deleted
    users_imported
    users_exported
    departments_imported
    departments_exported
    audit_events_exported
  ].freeze

  belongs_to :organization
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :target, polymorphic: true, optional: true

  validates :action, inclusion: { in: ACTIONS }
  belongs_to_same_organization :actor

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }

  # 保持期間を過ぎた記録。期間を指定していない場合は 1 件も含まない。
  #
  # 境界の時刻ちょうどは含めない。指定した日数は「残す期間」であり、
  # その端は残す側に入る。
  scope :expired, ->(at: Time.current) do
    days = Officeweave::Configuration::AuditRetention.days

    days ? where(created_at: ...(at - days.days)) : none
  end
  scope :with_action, ->(action) { where(action: action) if action.in?(ACTIONS) }
  scope :by_actor, ->(actor_id) { where(actor_id: actor_id) if actor_id.present? }

  # 記録を書き換えさせない。
  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }

  # 定期実行から呼ぶ。
  #
  # 削除は一括で行う。1 件ずつ destroy する形は、書き換えを禁じる仕掛けに
  # 阻まれるうえ、蓄積した記録の件数だけ問い合わせが増える。
  # 消した件数を返し、実行の記録から範囲を読み取れるようにする。
  def self.delete_expired(at: Time.current)
    expired(at: at).delete_all
  end

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
