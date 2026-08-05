# 申請の決裁をひとつの単位で確定する。
#
# 立場の判定、待っている段の確定、状態の変更、履歴、監査を、同じ行の占有の
# なかで行う。占有の前に判定すると、判定に使った段と、実際に処理する段が
# 食い違う。食い違いは、担当していない段を通せる形で現れる。
#
# 判定の結果は種類で返し、HTTP の状態への写し方は制御部へ委ねる。模型が
# 応答の形を知ると、同じ判断を画面と外部の経路でそろえられなくなる。
class RequestDecision
  # 決裁の種類。要求の値からは組み立てず、制御部が写した値だけを受ける。
  DECISIONS = %i[approve return].freeze

  # 結果の種類。
  #
  #   success             成立した
  #   stale               期待した段と、占有して読み直した段が違う
  #   unauthorized        占有して読み直した段の担当ではない
  #   invalid_transition  その状態からは決裁できない
  OUTCOMES = %i[success stale unauthorized invalid_transition].freeze

  attr_reader :outcome

  def self.call(...) = new(...).call

  def initialize(request:, actor:, decision:, expected_step_position:, comment: nil, ip_address: nil)
    @request = request
    @actor = actor
    @decision = decision
    @expected_step_position = expected_step_position
    @comment = comment
    @ip_address = ip_address
  end

  def call
    @request.with_lock { @outcome = decide }

    # 通知と外部への送信は確定したあとに行う。占有したまま外へ出ると、
    # 送信の遅れがそのまま他の決裁の待ち時間になる。
    # 成立しなかった決裁では組み立てていないため、何も起きない。
    @announce&.call

    self
  end

  def success? = outcome == :success

  private
    def decide
      return :invalid_transition unless @request.status == "pending"

      step = @request.current_step
      return :stale unless step && step.position == @expected_step_position
      # 立場は、占有して読み直した段に対して確かめる。
      return :unauthorized unless @request.decision_authorized_for?(@actor)

      # 代理元も、段を動かす前に解く。動かしたあとに解くと、
      # 次の段の担当を代理元として残すことになる。
      on_behalf_of = @request.delegated_approver_for(@actor)

      @decision == :approve ? approve(step, on_behalf_of) : return_to_applicant(step, on_behalf_of)
    end

    def approve(step, on_behalf_of)
      following = @request.next_step

      if following
        advance_to(following, step, on_behalf_of)
      else
        conclude(step, on_behalf_of)
      end

      :success
    end

    # 次の段へ進める。状態は承認待ちのままとする。
    #
    # 承認済みへ至らない承認も、誰がいつどの段を通したのかを残す。
    # 監査の種別も承認とする。状態から組み立てると、承認待ちのまま進んだ
    # ことが、そのまま許可されていない種別になる。
    def advance_to(following, step, on_behalf_of)
      approvers = @request.approvers(following)

      @request.update!(current_step_position: following.position)
      record(step: step, action: "approved", audit: "request_approved", on_behalf_of: on_behalf_of)

      @announce = -> { Notification.deliver_to_all(users: approvers, subject: @request, event: "request_submitted") }
    end

    # 最後の段の承認。ここで承認済みとする。
    def conclude(step, on_behalf_of)
      @request.update!(status: "approved", decided_at: Time.current)
      record(step: step, action: "approved", audit: "request_approved", on_behalf_of: on_behalf_of)

      announce_to_applicant("request_approved")
    end

    def return_to_applicant(step, on_behalf_of)
      @request.update!(status: "returned", decided_at: Time.current)
      # 差し戻しは、その段を通していない。段への印は残さない。
      record(step: step, action: "returned", audit: "request_returned",
             on_behalf_of: on_behalf_of, approve_step: false)

      announce_to_applicant("request_returned")

      :success
    end

    # 段の承認、履歴、監査を、状態の変更と同じ占有のなかで残す。
    #
    # 写した経路が無い申請では、段への印を残す先が無い。その場合は何もしない。
    def record(step:, action:, audit:, on_behalf_of:, approve_step: true)
      step.record_approval!(actor: @actor) if approve_step && step.is_a?(RequestApprovalStep)

      @request.request_activities.create!(
        actor: @actor, action: action, comment: @comment,
        step_position: step.position, on_behalf_of: on_behalf_of
      )

      # 監査へ残すのは、何が起きたかを追える最小限とする。
      # 本文とコメントは入れない。決裁の理由は履歴が持つ。
      AuditEvent.record(
        organization: @request.organization, actor: @actor, action: audit,
        target: @request, details: { title: @request.title }, ip_address: @ip_address
      )
    end

    def announce_to_applicant(event)
      applicant = @request.applicant
      organization = @request.organization

      @announce = lambda do
        Notification.deliver(user: applicant, subject: @request, event: event)
        Notification.publish(organization: organization, subject: @request, event: event)
      end
    end
end
