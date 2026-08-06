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
  #   stale               要求を作った時点の状態と、占有して読み直した状態が違う
  #   unauthorized        占有して読み直した段の担当ではない
  #   invalid_transition  その状態からは決裁できない
  #   invalid_decision    決裁の種類が許可された値ではない
  OUTCOMES = %i[success stale unauthorized invalid_transition invalid_decision].freeze

  attr_reader :outcome

  def self.call(...) = new(...).call

  def initialize(request:, actor:, decision:, expected_step_position:, state_token:,
                 comment: nil, ip_address: nil)
    @request = request
    @actor = actor
    @decision = decision
    @expected_step_position = expected_step_position
    @state_token = state_token
    @comment = comment
    @ip_address = ip_address
  end

  def call
    # 許可された種類かどうかは、占有する前に確かめる。
    # 一覧に無い値をここで落とさないと、承認でないものが差し戻しとして通る。
    return tap { @outcome = :invalid_decision } unless DECISIONS.include?(@decision)

    @request.with_lock { @outcome = decide }

    # 通知と外部への送信は、いちばん外側の確定のあとに行う。
    #
    # 占有したまま外へ出ると、送信の遅れがそのまま他の決裁の待ち時間になる。
    # 直後に呼ぶだけでは足りない。この決裁が外側のトランザクションから
    # 呼ばれた場合、占有はそちらへ加わるため、確定はまだ終わっていない。
    # 戻された処理の通知だけが残る。
    #
    # 成立しなかった決裁では組み立てていないため、何も登録しない。
    ActiveRecord.after_all_transactions_commit { announce_safely } if @announce

    self
  end

  def success? = outcome == :success

  private
    # 判定の順は、返す理由が食い違わないように決めてある。
    #
    #   1. 段        位置が違えば、その先は問うだけ無駄である
    #   2. 立場      担当でないことは、状態より先に伝える。担当外へ競合を
    #                返すと、待てば通ると読める
    #   3. 見ていた状態  担当であっても、見ていたものが古ければ競合とする
    #   4. 遷移      ここまで通って初めて、いまの状態から動かせるかを問う
    #
    # 状態の確認を先に置かない。置くと、画面を開いたあとに承認済みや差し戻し
    # まで進んだ場合だけ、競合ではなく一般の失敗として返る。古い要求である
    # ことは同じであり、扱いを分ける理由がない。
    def decide
      step = @request.current_step
      return :stale unless step && step.position == @expected_step_position

      # 立場は、占有して読み直した段と、読み直した利用者に対して確かめる。
      #
      # 呼び出しのときに読んだ利用者をそのまま使わない。読んでから決裁するまでの
      # あいだに、利用を止められたり立場が変わったりする。手元の写しは古いまま
      # 有効に見える。行を占有して、いまの利用者を取り直す。
      #
      # 立場と代理元は 1 回で解く。別々に解くと、そのあいだに委任が変わった
      # 場合に、委任で通したのに代理元が残らない、という食い違いが起きる。
      @authorization = @request.decision_authorization_for(locked_actor, lock: true)
      return :unauthorized if @authorization.nil?

      # 位置が合うだけでは足りない。位置は同じ値へ戻り得るため、要求を作った
      # 時点の申請そのものまで照らす。
      return :stale unless RequestDecisionToken.matches?(@state_token, request: @request,
                                                         actor: @authorization.actor)
      return :invalid_transition unless @request.status == "pending"

      @decision == :approve ? approve(step) : return_to_applicant(step)
    end

    # 決裁するのは、占有して取り直した利用者である。
    # 記録もすべてこの利用者で残す。判定と記録で別の写しを使わない。
    def actor = @authorization.actor

    def locked_actor
      @request.organization.users.lock.find_by(id: @actor.id)
    end

    def approve(step)
      following = @request.next_step

      following ? advance_to(following, step) : conclude(step)

      :success
    end

    # 次の段へ進める。状態は承認待ちのままとする。
    #
    # 承認済みへ至らない承認も、誰がいつどの段を通したのかを残す。
    # 監査の種別も承認とする。状態から組み立てると、承認待ちのまま進んだ
    # ことが、そのまま許可されていない種別になる。
    def advance_to(following, step)
      approvers = @request.approvers(following)

      @request.update!(current_step_position: following.position)
      activity = record(step: step, action: "approved", audit: "request_approved")
      occurrence = occurrence_for(activity)

      @announce = lambda do
        Notification.deliver_to_all(users: approvers, subject: @request, event: "request_submitted",
                                    occurrence: occurrence)
      end
    end

    # 最後の段の承認。ここで承認済みとする。
    def conclude(step)
      @request.update!(status: "approved", decided_at: Time.current)
      activity = record(step: step, action: "approved", audit: "request_approved")

      announce_to_applicant("request_approved", activity)
    end

    def return_to_applicant(step)
      @request.update!(status: "returned", decided_at: Time.current)
      # 差し戻しは、その段を通していない。段への印は残さない。
      activity = record(step: step, action: "returned", audit: "request_returned", approve_step: false)

      announce_to_applicant("request_returned", activity)

      :success
    end

    # 段の承認、履歴、監査を、状態の変更と同じ占有のなかで残す。
    #
    # 写した経路が無い申請では、段への印を残す先が無い。その場合は何もしない。
    def record(step:, action:, audit:, approve_step: true)
      step.record_approval!(actor: actor) if approve_step && step.is_a?(RequestApprovalStep)

      activity = @request.request_activities.create!(
        actor: actor, action: action, comment: @comment,
        step_position: step.position, on_behalf_of: @authorization.on_behalf_of
      )

      # 監査へ残すのは、何が起きたかを追える最小限とする。
      # 本文とコメントは入れない。決裁の理由は履歴が持つ。
      AuditEvent.record(
        organization: @request.organization, actor: actor, action: audit,
        target: @request, details: { title: @request.title }, ip_address: @ip_address
      )

      # 通知の発生を表す値の元になる。同じ決裁で何度呼んでも同じ値になる。
      activity
    end

    # 確定した決裁を、知らせに失敗しただけで失敗として返さない。
    #
    # ここへ来た時点で、申請、段の印、履歴、監査は確定している。送出すると、
    # 画面には失敗が出るのに保存されているのは決裁済み、という食い違いが
    # 通知の側から生まれる。それは今回直している状態そのものである。
    #
    # 記録へは残す。黙って落とすと、届いていないことに気付く手がかりがない。
    # 決裁の内容は文脈へ入れない。申請の識別子だけで、どの決裁かは辿れる。
    def announce_safely
      @announce.call
    rescue StandardError => error
      Rails.error.report(error, handled: true,
                         context: { announce: "request_decision", request_id: @request.id })
    end

    # 発生は、その決裁を表す履歴の識別子とする。同じ利用者が複数の段を
    # 担当する場合も、段ごとに別の履歴になるため、それぞれで未読が作られる。
    def announce_to_applicant(event, activity)
      applicant = @request.applicant
      organization = @request.organization
      occurrence = occurrence_for(activity)

      @announce = lambda do
        Notification.deliver(user: applicant, subject: @request, event: event, occurrence: occurrence)
        Notification.publish(organization: organization, subject: @request, event: event,
                             occurrence: occurrence)
      end
    end

    def occurrence_for(activity)
      activity ? "activity:#{activity.id}" : Notification::DEFAULT_OCCURRENCE
    end
end
