# 申請。提出、承認、差し戻し、取り下げの状態を持つ。
#
# 状態はひとつの列で表す。複数の真偽値で表すと、
# 承認済みかつ差し戻し済みのような、あり得ない組み合わせを作れてしまう。
class Request < ApplicationRecord
  STATUSES = %w[draft pending approved returned withdrawn].freeze

  # 各状態から移れる先。ここにない移動は受け付けない。
  ALLOWED_TRANSITIONS = {
    "draft" => %w[pending withdrawn],
    "pending" => %w[approved returned withdrawn],
    "returned" => %w[pending withdrawn],
    "approved" => [],
    "withdrawn" => []
  }.freeze

  belongs_to :organization
  belongs_to :request_type
  belongs_to :applicant, class_name: "User"

  has_many :request_activities, dependent: :destroy
  has_many :notifications, as: :subject, dependent: :destroy

  validates :title, presence: true, length: { maximum: 200 }
  validates :body, length: { maximum: 10_000 }
  validates :status, inclusion: { in: STATUSES }
  belongs_to_same_organization :applicant, :request_type
  validate :request_type_must_be_active, on: :create

  scope :recent_first, -> { order(created_at: :desc, id: :desc) }
  scope :applied_by, ->(user) { where(applicant_id: user.id) }

  # 一覧に並べる列だけを選ぶ。
  #
  # 本文は最大 10,000 文字あり、一覧では表示しない。全列を返すと、
  # 表示しない本文が申請の件数だけ Rails process へ渡る。
  #
  # 申請者と種別の外部キーは残す。落とすと先読みが成立せず、
  # 申請の件数だけ問い合わせが増える。
  scope :listed, -> { select(:id, :title, :status, :applicant_id, :request_type_id) }


  # その利用者が処理を待たれている申請。
  # 自分の申請は自分で承認できないため、対象から外す。
  scope :awaiting_decision_by, ->(user) {
    where(organization_id: user.organization_id, status: "pending")
      .where.not(applicant_id: user.id)
      .where(request_type_id: approvable_request_types(user))
  }
  # 単一の状態でも、複数の状態の並びでも絞り込める。
  scope :with_status, ->(status) {
    values = Array(status) & STATUSES
    where(status: values) if values.any?
  }

  # 一度でも提出されたもの。
  #
  # 提出は、申請者が内容を承認担当者へ渡す操作である。submitted_at は提出で
  # 一度だけ入り、その後の差し戻しでも取り下げでも消えない。
  #
  # status では判断しない。差し戻しと取り下げは、提出を経た場合と経ていない
  # 場合の両方があり、status は同じ値になる。
  scope :submitted, -> { where.not(submitted_at: nil) }

  # 申請者本人と、承認できる利用者だけが参照できる。
  #
  # 申請者は、提出の有無に関わらず自分の申請を参照できる。
  # 承認担当者と管理者は、提出されたものだけを参照できる。提出前の下書きは、
  # 申請者がまだ渡していない内容であり、渡す操作より前から見せない。
  scope :visible_to, ->(user) {
    in_organization = where(organization_id: user.organization_id)

    in_organization.applied_by(user).or(
      in_organization.submitted.where(request_type_id: approvable_request_types(user))
    )
  }

  # その利用者が承認を担当する申請種別。
  # 管理者はすべての種別を担当する。
  def self.approvable_request_types(user)
    return RequestType.where(organization_id: user.organization_id).select(:id) if user.administrator?

    RequestType
      .where(approver_department_id: Membership.where(user_id: user.id).select(:department_id))
      .select(:id)
  end

  def can_transition_to?(next_status)
    ALLOWED_TRANSITIONS.fetch(status, []).include?(next_status)
  end

  def editable_by?(user)
    applicant_id == user.id && status.in?(%w[draft returned])
  end

  def withdrawable_by?(user)
    applicant_id == user.id && can_transition_to?("withdrawn")
  end

  def submit(actor:)
    changed = change_status(to: "pending", actor: actor, action: "submitted") do
      self.submitted_at = Time.current
    end

    notify_approvers if changed
    changed
  end

  def withdraw(actor:)
    change_status(to: "withdrawn", actor: actor, action: "withdrawn")
  end

  def approve(actor:, comment: nil)
    decide(to: "approved", action: "approved", actor: actor, comment: comment, event: "request_approved")
  end

  def return_to_applicant(actor:, comment: nil)
    decide(to: "returned", action: "returned", actor: actor, comment: comment, event: "request_returned")
  end

  # 承認を担当する利用者。
  def approvers
    department_id = request_type.approver_department_id

    scope = organization.users.active
    scope = department_id ? scope.where(id: Membership.where(department_id: department_id).select(:user_id))
                          : scope.where(role: "administrator")
    scope.where.not(id: applicant_id)
  end

  def record_creation(actor:)
    request_activities.create!(actor: actor, action: "created")
  end

  # 承認と差し戻しを任されている利用者かどうか。
  # 自分の申請は自分で承認できない。
  #
  # 現在の状態は見ない。状態は競合で変わり得るため、
  # 実際に処理できるかどうかは行を占有した change_status だけが決める。
  def decision_authorized_for?(user)
    applicant_id != user.id && request_type.approvable_by?(user)
  end

  # 決裁の操作を画面へ出してよいかどうか。
  def decidable_by?(user)
    status == "pending" && decision_authorized_for?(user)
  end

  private
    def decide(to:, action:, actor:, comment:, event:)
      changed = change_status(to: to, actor: actor, action: action, comment: comment) do
        self.decided_at = Time.current
      end

      if changed
        Notification.deliver(user: applicant, subject: self, event: event)
        Notification.publish(organization: organization, subject: self, event: event)
      end

      changed
    end

    def notify_approvers
      Notification.deliver_to_all(users: approvers, subject: self, event: "request_submitted")
      Notification.publish(organization: organization, subject: self, event: "request_submitted")
    end

    # 状態の変更と記録を必ず一緒に行う。
    # 別々に書くと、記録の漏れた変更が生まれる。
    #
    # 遷移できるかどうかは、行を占有して読み直した状態だけで決める。
    # 読み込みのあとに判定すると、同じ承認待ちを見た承認と差し戻しが
    # 両方成立し、履歴と通知が食い違ったまま残る。
    #
    # 通知や外部への送信はここへ含めない。占有したまま外部を待つと、
    # 送信の遅れがそのまま他の操作の待ち時間になる。
    def change_status(to:, actor:, action:, comment: nil)
      changed = false

      with_lock do
        next unless can_transition_to?(to)

        self.status = to
        yield if block_given?
        save!
        request_activities.create!(actor: actor, action: action, comment: comment)
        changed = true
      end

      changed
    end

    def request_type_must_be_active
      return if request_type.nil? || request_type.active?

      errors.add(:request_type, :not_active)
    end
end
