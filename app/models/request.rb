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
  # 提出の時点の段を写した経路。
  has_many :request_approval_steps, -> { ordered }, dependent: :destroy, inverse_of: :request
  has_many :notifications, as: :subject, dependent: :destroy

  # 決裁の要求が、どの時点の申請に対して作られたのかを見分ける値。
  #
  # 状態、待っている段、提出、内容のいずれかが変わるたびに作り直す。
  # 順序は持たせない。持たせると、占有していない経路（内容の編集）から
  # 同じ値を 2 つ作り得る。
  DECISION_STATE_ATTRIBUTES = %w[status current_step_position submitted_at title body].freeze

  before_validation :renew_decision_state_nonce, if: :decision_state_changing?

  validates :title, presence: true, length: { maximum: 200 }
  validates :decision_state_nonce, presence: true
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
  #
  # 現在の段の担当だけを対象にする。先の段の担当は、その段へ進むまで
  # 待たれていない。自分の申請は自分で承認できないため、対象から外す。
  scope :awaiting_decision_by, ->(user) {
    scope = where(organization_id: user.organization_id, status: "pending")
              .where.not(applicant_id: user.id)

    # 管理者はすべての段を担当する。段を持つ前からの範囲を狭めない。
    user.administrator? ? scope : scope.where(current_step_approvable_by(user))
  }

  # 題名と本文の部分一致で引く。文書とお知らせと同じ書き方でそろえる。
  scope :search, ->(query) {
    term = query.to_s.strip
    next if term.blank?

    pattern = "%#{sanitize_sql_like(term)}%"
    where(arel_table[:title].matches(pattern).or(arel_table[:body].matches(pattern)))
  }

  # 種別での絞り込み。指定が無ければ全件を返す。
  scope :with_request_type, ->(request_type_id) {
    next if request_type_id.blank?

    where(request_type_id: request_type_id)
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
  #
  # いずれかの段を担当していれば、その種別の申請を参照できる。
  # 実際に決裁できるかどうかは、現在の段が決める。
  # 管理者はすべての種別を担当する。
  def self.approvable_request_types(user)
    if user.administrator? || DelegatedApproval.administrator?(user)
      return RequestType.where(organization_id: user.organization_id).select(:id)
    end

    ApprovalStep.where(approver_department_id: approvable_department_ids(user)).select(:request_type_id)
  end

  # 現在の段が、その利用者の担当である申請。
  #
  # 段は種別ごとの並びで決まる。申請が持つのは待っている段の並びの値であり、
  # 段そのものへの参照ではない。段の構成を後から変えても、待っている位置が
  # 別の段へずれない。
  def self.current_step_approvable_by(user)
    # 写した経路があればそちらを見る。無い申請は種別の段を見る。
    snapshot = RequestApprovalStep
                 .where(RequestApprovalStep.arel_table[:request_id].eq(arel_table[:id]))
                 .where(RequestApprovalStep.arel_table[:position].eq(arel_table[:current_step_position]))
                 .where(step_charge_of(user, RequestApprovalStep))

    template = ApprovalStep
                 .where(ApprovalStep.arel_table[:request_type_id].eq(arel_table[:request_type_id]))
                 .where(ApprovalStep.arel_table[:position].eq(arel_table[:current_step_position]))
                 .where(step_charge_of(user, ApprovalStep))

    snapshot.arel.exists.or(
      template.arel.exists.and(
        RequestApprovalStep.where(RequestApprovalStep.arel_table[:request_id].eq(arel_table[:id]))
                           .arel.exists.not
      )
    )
  end

  # その段を担当できる条件。
  #
  # 部門を指定しない段は管理者が担当する。管理者から委任を受けている利用者も、
  # その段を担当できる。部門で照らすだけだと、この段が一覧から落ちる。
  def self.step_charge_of(user, step_class)
    in_department = step_class.arel_table[:approver_department_id].in(
      approvable_department_ids(user).arel
    )

    return in_department unless DelegatedApproval.administrator?(user)

    in_department.or(step_class.arel_table[:approver_department_id].eq(nil))
  end

  # その利用者が担当として扱われる部門。
  #
  # 自分の所属に加えて、委任を受けている相手の所属を含める。
  # 委任は担当を移さない。決裁できる範囲だけを広げる。
  def self.approvable_department_ids(user)
    # 委任元は副問い合わせのまま渡す。配列へ展開すると、委任の件数だけ
    # 問い合わせが増える。
    Membership.where(user_id: user.id).select(:department_id).or(
      DelegatedApproval.department_ids(user)
    )
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
      # 提出の時点の段を写す。写した経路は、種別の段を後から変えても変わらない。
      # 再提出では取り直す。そのときの段が、その提出の経路になる。
      snapshot_route
      # 提出のたびに 1 段目から始める。差し戻しのあとの再提出も同じとする。
      # 途中まで進んだ経路を、内容を直したあとも引き継がない。
      self.current_step_position = route_steps.first&.position || 0
    end

    notify_approvers(latest_activity) if changed
    changed
  end

  def withdraw(actor:)
    change_status(to: "withdrawn", actor: actor, action: "withdrawn")
  end

  # 現在の段を承認する。
  #
  # 次の段があれば、その段を待つ状態のまま進める。最後の段であれば承認済みとする。
  #
  # 判定と記録は RequestDecision が持つ。ここへ置くと、立場の判定だけが
  # 呼び出し側へ散り、占有の外で判定する形へ戻る。
  def approve(actor:, comment: nil, expected_step_position: nil, state_token: nil)
    commit_decision(:approve, actor: actor, comment: comment,
                    expected_step_position: expected_step_position, state_token: state_token)
  end

  def return_to_applicant(actor:, comment: nil, expected_step_position: nil, state_token: nil)
    commit_decision(:return, actor: actor, comment: comment,
                    expected_step_position: expected_step_position, state_token: state_token)
  end

  # 決裁の画面が、いま見えている状態を持ち帰るための値。
  def decision_state_token_for(user)
    RequestDecisionToken.issue(request: self, actor: user)
  end

  # この申請が通る経路。
  #
  # 写した経路があればそれを使う。無い場合は種別の段を経路として扱う。
  # 写す仕組みより前に提出された申請には、写した経路が無い。
  def route_steps
    steps = request_approval_steps.to_a

    steps.presence || request_type.approval_steps.ordered.to_a
  end

  # 現在待っている段。段の構成が変わった場合は、その並び以降の最初の段とする。
  def current_step = route_steps.detect { |step| step.position >= current_step_position }

  # 現在の段の次にある段。無ければ nil。
  def next_step = route_steps.detect { |step| step.position > current_step_position }

  # 現在の段の承認を担当する利用者。
  #
  # 委任を受けている利用者も含める。含めないと、代わりに決裁する相手が
  # 待っていることに気付けない。
  def approvers(step = current_step)
    return organization.users.none if step.nil?

    responsible = step.approvers(organization)
    delegates = DelegatedApproval.delegates_of(responsible)

    organization.users.active.where(id: responsible.select(:id)).or(
      organization.users.active.where(id: delegates.select(:id))
    ).where.not(id: applicant_id)
  end

  def record_creation(actor:)
    request_activities.create!(actor: actor, action: "created")
  end

  # 決裁の立場と、その根拠。
  #
  # 立場の判定と代理元の解決を別々に行わない。分けると、そのあいだに委任が
  # 変わった場合に、委任で通したのに代理元が残らない、という食い違いが起きる。
  DecisionAuthorization = Data.define(:actor, :on_behalf_of, :source)

  # 承認と差し戻しを任されているかどうかを解き、根拠ごと返す。
  # 任されていない場合は nil を返す。
  #
  # 現在の状態は見ない。状態は競合で変わり得るため、実際に処理できるかどうかは
  # 行を占有した決裁だけが決める。
  #
  # 立場の判定は、この 1 か所で完結させる。制御部の参照範囲に頼ると、
  # 画面を通らない経路から呼んだときに、その分の判定が抜ける。
  def decision_authorization_for(user, lock: false)
    return nil if user.nil?
    return nil unless user.active?
    return nil unless user.organization_id == organization_id
    return nil if applicant_id == user.id

    step = current_step

    # 段が無い場合は、種別の担当（管理者）へ委ねる。
    return authorization(user, source: :administrator) if step.nil? && user.administrator?
    return nil if step.nil?
    return authorization(user, source: :responsible) if step.approvable_by?(user)

    # 委任を受けている相手が担当なら、代わりに決裁できる。
    delegator = delegators_of(user, lock: lock).detect { |candidate| step.approvable_by?(candidate) }
    return nil if delegator.nil?

    authorization(user, on_behalf_of: delegator, source: :delegated)
  end

  def decision_authorized_for?(user)
    decision_authorization_for(user).present?
  end

  # 決裁の操作を画面へ出してよいかどうか。
  def decidable_by?(user)
    status == "pending" && decision_authorized_for?(user)
  end

  private
    def authorization(user, on_behalf_of: nil, source:)
      DecisionAuthorization.new(actor: user, on_behalf_of: on_behalf_of, source: source)
    end

    def decision_state_changing?
      new_record? || DECISION_STATE_ATTRIBUTES.any? { |name| will_save_change_to_attribute?(name) }
    end

    def renew_decision_state_nonce
      self.decision_state_nonce = SecureRandom.hex(16)
    end

    # その利用者が代わりに決裁できる相手。
    #
    # 決裁のときは占有して読む。読んだあとに委任を取り消されると、取り消し後の
    # 決裁が通り得る。占有する順は、申請、決裁する利用者、委任元の識別子順と
    # 決めてある。画面の表示では占有しない。表示のたびに他の利用者の行を
    # 押さえることになる。
    def delegators_of(user, lock: false)
      scope = organization.users.where(id: ApprovalDelegation.delegators_for(user))
      scope = scope.order(:id).lock if lock

      scope.to_a
    end

    # 提出の時点の段を写す。前の提出の分は残さない。
    def snapshot_route
      request_approval_steps.destroy_all if persisted? && request_approval_steps.exists?

      request_type.approval_steps.ordered.each do |step|
        request_approval_steps.build(step.snapshot_attributes)
      end
    end

    # 指定が無い呼び出しは、いま見えている状態を期待したものとして扱う。
    # 画面からの決裁では、制御部が要求の値を渡す。
    #
    # 値は占有する前に作る。占有したあとに作ると、そのあいだに起きた変更を
    # 自分で打ち消すことになり、競合を見つけられなくなる。
    def commit_decision(decision, actor:, comment:, expected_step_position:, state_token:)
      RequestDecision.call(
        request: self, actor: actor, decision: decision, comment: comment,
        expected_step_position: expected_step_position || current_step&.position,
        state_token: state_token || decision_state_token_for(actor)
      ).success?
    end

    # 発生は、その提出を表す履歴の識別子とする。差し戻したあとの再提出は
    # 別の履歴になるため、承認者へ新しい未読が作られる。やり直しでは同じ
    # 履歴を指すため、増えない。
    def notify_approvers(activity)
      occurrence = occurrence_for(activity)

      Notification.deliver_to_all(users: approvers, subject: self, event: "request_submitted",
                                  occurrence: occurrence)
      Notification.publish(organization: organization, subject: self, event: "request_submitted",
                           occurrence: occurrence)
    end

    def latest_activity
      request_activities.order(:id).last
    end

    def occurrence_for(activity)
      activity ? "activity:#{activity.id}" : Notification::DEFAULT_OCCURRENCE
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
    def change_status(to:, actor:, action:, comment: nil, step_position: nil, on_behalf_of: nil)
      changed = false

      with_lock do
        next unless can_transition_to?(to)

        self.status = to
        yield if block_given?
        save!
        request_activities.create!(actor: actor, action: action, comment: comment,
                                  step_position: step_position, on_behalf_of: on_behalf_of)
        changed = true
      end

      changed
    end

    def request_type_must_be_active
      return if request_type.nil? || request_type.active?

      errors.add(:request_type, :not_active)
    end
end
