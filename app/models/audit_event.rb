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

  # 詳細へ置いてよいのは、記録を識別できる短い値だけとする。
  #
  # 監査は、誰が何をしたかを追うためのものであり、業務の内容の写しではない。
  # 本文やコメントを写すと、記録の側に別の保持期間と別の読み手を持つ複製が
  # できる。秘密や token を写せば、監査を読める相手がそのまま使える。
  #
  # 判断は書く側に任せず、保存の直前で必ず取り除く。書く場所は増えていく。
  FORBIDDEN_DETAIL_KEYS = /password|secret|token|credential|body|comment|content|description/i

  # 1 つの値の長さの上限。
  #
  # 鍵の名前だけでは、自由に書ける文章が別の名前で入ってくるのを止められない。
  # 識別に使う値は短い。長い値は、内容そのものだと見なして切り詰める。
  MAXIMUM_DETAIL_LENGTH = 200

  # 取り除いたことを残す。黙って消すと、書いたつもりの値が無いのか、
  # そもそも書かれなかったのかを、後から区別できない。
  REDACTED = "[取り除いた]".freeze
  TRUNCATED = "…[切り詰めた]".freeze

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

  before_validation :sanitize_details

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

  private
    def sanitize_details
      self.details = self.class.sanitized_details(details)
    end

    class << self
      # 入れ子も同じ規則で見る。1 段目だけを見ると、まとめた鍵の下へ
      # 置くだけで通り抜ける。
      def sanitized_details(value)
        case value
        when Hash
          value.to_h { |key, nested| [ key, forbidden_key?(key) ? REDACTED : sanitized_details(nested) ] }
        when Array
          value.map { |nested| sanitized_details(nested) }
        when String
          truncated(value)
        else
          value
        end
      end

      private
        def forbidden_key?(key)
          key.to_s.match?(FORBIDDEN_DETAIL_KEYS)
        end

        def truncated(value)
          return value if value.length <= MAXIMUM_DETAIL_LENGTH

          value[0, MAXIMUM_DETAIL_LENGTH] + TRUNCATED
        end
    end
end
