require "test_helper"
require "timeout"

# 同じ申請へ競合する状態変更が同時に届いた場合の確認。
#
# 直前に読み取った状態で判定すると、承認と差し戻しの両方が成立し、
# 履歴と通知が食い違ったまま残る。それを確かめるには別々の接続から
# 同時に処理する必要があるため、このクラスだけトランザクションで囲む既定を外す。
#
# 決裁だけでなく、提出と取り下げも同じ change_status を通る。
# 経路が同じであることに頼らず、それぞれの競合を直接確かめる。
class RequestConcurrencyTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper

  include IsolatedOrganizationTestHelper

  self.use_transactional_tests = false

  ORGANIZATION_CODE = "request-concurrency".freeze

  # 決裁ごとに違う理由を渡す。敗れた側の理由が履歴へ残っていないことを見るため。
  DECISION_COMMENTS = { "approved" => "承認の理由", "returned" => "差し戻しの理由" }.freeze

  # 多段の経路の段。3 段目は部門を指定せず、管理者が担当する段とする。
  MULTI_FIRST = 10
  MULTI_SECOND = 20
  MULTI_LAST = 30

  # 待機はすべて上限を持たせる。退行を CI の停止ではなく失敗として受け取るため。
  PREPARATION_TIMEOUT = 10
  COMPLETION_TIMEOUT = 30
  OUTCOME_TIMEOUT = 5
  CLEANUP_TIMEOUT = 5

  setup do
    @organization = create_isolated_organization(name: "申請の同時実行", code: ORGANIZATION_CODE)
    @department = @organization.departments.create!(name: "総務部", code: "general-affairs")
    @applicant = create_user("applicant@example.com", role: "member")
    @approver = create_user("approver@example.com", role: "administrator")
    @approver.memberships.create!(department: @department)
    @request_type = @organization.request_types.create!(
      name: "休暇届", code: "leave",
      approval_steps_attributes: [ { position: 10, approver_department_id: @department.id } ]
    )
    @endpoint = @organization.webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")
    @request = create_request(status: "pending", submitted_at: 1.day.ago)
  end

  teardown do
    discard_organization(@organization)
  end

  test "承認と差し戻しが同時に届いても成立するのは片方だけ" do
    outcomes = concurrently(approve, return_to_applicant)

    assert_equal 1, outcomes.count(true)
    assert_equal 1, outcomes.count(false)
    assert_includes %w[approved returned], @request.reload.status
    assert_not_nil @request.decided_at
  end

  test "承認と差し戻しが競合しても決裁の履歴は 1 件だけ残る" do
    concurrently(approve, return_to_applicant)

    activity = decision_activities.sole

    assert_equal @request.reload.status, activity.action
    assert_equal DECISION_COMMENTS.fetch(activity.action), activity.comment
  end

  test "承認と差し戻しが競合しても申請者への通知は最終の状態だけになる" do
    concurrently(approve, return_to_applicant)

    notification = decision_notifications.sole

    assert_equal "request_#{@request.reload.status}", notification.event
  end

  test "承認と差し戻しが競合してもメールの送信は成立した決裁のぶんだけ積まれる" do
    assert_enqueued_emails 1 do
      concurrently(approve, return_to_applicant)
    end
  end

  test "承認と差し戻しが競合しても外部への送信は成立した決裁のぶんだけ積まれる" do
    concurrently(approve, return_to_applicant)

    assert_equal [ "request_#{@request.reload.status}" ], enqueued_webhook_events
  end

  test "同じ承認が二重に届いても成立するのは 1 件だけ" do
    outcomes = concurrently(approve, approve)

    assert_equal 1, outcomes.count(true)
    assert_equal 1, outcomes.count(false)
    assert_equal "approved", @request.reload.status
    assert_equal 1, decision_activities.count
    assert_equal 1, decision_notifications.count
  end

  test "同じ取り下げが二重に届いても成立するのは 1 件だけ" do
    outcomes = concurrently(withdraw, withdraw)

    assert_equal 1, outcomes.count(true)
    assert_equal 1, outcomes.count(false)
    assert_equal "withdrawn", @request.reload.status
    assert_equal 1, @request.request_activities.where(action: "withdrawn").count
  end

  test "同じ提出が二重に届いても成立するのは 1 件だけ" do
    draft = create_request(status: "draft")

    outcomes = concurrently(submit, submit, request: draft)

    assert_equal 1, outcomes.count(true)
    assert_equal 1, outcomes.count(false)
    assert_equal "pending", draft.reload.status
    assert_not_nil draft.submitted_at
    assert_equal 1, draft.request_activities.where(action: "submitted").count
  end

  test "二重の提出でも承認者への知らせは成立した提出のぶんだけになる" do
    draft = create_request(status: "draft")

    concurrently(submit, submit, request: draft)

    assert_equal 1, Notification.where(user: @approver, subject: draft, event: "request_submitted").count

    # 複数の受け手への送信は、要求の中では 1 件しか積まない。
    # 受け手ごとの送信はワーカーが積む。
    perform_enqueued_jobs(only: NotificationMailFanoutJob)

    assert_enqueued_emails 1
    assert_equal [ "request_submitted" ], enqueued_webhook_events
  end

  test "承認と取り下げが同時に届いても成立するのは片方だけ" do
    outcomes = concurrently(approve, withdraw)

    assert_equal 1, outcomes.count(true)
    assert_equal 1, outcomes.count(false)
    assert_includes %w[approved withdrawn], @request.reload.status
  end

  test "承認と取り下げが競合しても履歴は最終の状態のものだけになる" do
    concurrently(approve, withdraw)

    activity = @request.request_activities.where(action: %w[approved withdrawn]).sole

    assert_equal @request.reload.status, activity.action
  end

  # 取り下げには知らせる出来事がない。取り下げが先に成立した場合は、
  # 決裁の通知も送信も作らないことまで確かめる。
  test "承認と取り下げが競合しても決裁の知らせは最終の状態に対応する" do
    concurrently(approve, withdraw)

    decided = @request.reload.status == "approved" ? 1 : 0

    assert_equal decided, decision_notifications.count
    assert_enqueued_emails decided
    assert_equal [ "request_approved" ] * decided, enqueued_webhook_events
  end

  # 副作用の件数だけを見ると、片方が例外で終わっても、もう片方の成功で数が合う。
  # thread の中で起きた例外は、必ずテストの失敗として受け取る。
  test "処理の途中で例外が起きた場合は副作用の件数が揃っていても失敗する" do
    failure = assert_raises(Minitest::Assertion) do
      concurrently(approve, ->(_request) { raise ActiveRecord::RecordNotFound, "対象が見つかりません" })
    end

    assert_includes failure.message, "ActiveRecord::RecordNotFound"
    assert_includes failure.message, "対象が見つかりません"
    assert_equal 1, decision_activities.count
  end

  test "状態を変える処理では申請の行をロックする" do
    statements = locking_statements { @request.approve(actor: @approver) }

    assert_predicate statements, :any?
  end

  # 多段の経路。
  #
  # 段ごとに担当を分けないと、段が進んだかどうかが担当の違いに現れない。
  # 立場の判定を占有の外で行っていた頃は、段 1 の担当だけで先の段まで通せた。
  test "同じ段への二重の承認でも進むのは 1 段だけ" do
    request = multi_step_request

    outcomes = concurrently(approve_by(@first_approver, MULTI_FIRST),
                            approve_by(@first_approver, MULTI_FIRST), request: request)

    assert_equal 1, outcomes.count(true)
    assert_equal MULTI_SECOND, request.reload.current_step_position
    assert_equal 1, request.request_activities.where(action: "approved").count
  end

  # 段 1 を待っているあいだ、画面が段 2 の担当へ出すのは段 1 である。
  # 両者が同じ段を指して同時に決裁しても、成立するのは担当している側だけとする。
  #
  # 段 2 の担当が段 2 を指した要求は、署名した値が段 1 の状態を指すため通らない。
  # 別に「先の段を指して先に用意した要求」で確かめている。
  test "段 1 と段 2 の担当が同じ段へ同時に決裁しても成立するのは担当だけ" do
    request = multi_step_request

    outcomes = concurrently(approve_by(@first_approver, MULTI_FIRST),
                            approve_by(@second_approver, MULTI_FIRST), request: request)

    assert_equal 1, outcomes.count(true)
    assert_equal MULTI_SECOND, request.reload.current_step_position
    assert_equal @first_approver, request.request_activities.where(action: "approved").sole.actor
  end

  # すべての段を担当する利用者では、占有のなかの立場の判定だけでは足りない。
  # 期待した段との一致が、二重送信を止める唯一の手立てになる。
  test "すべての段を担当する利用者の二重送信でも進むのは 1 段だけ" do
    request = multi_step_request

    outcomes = concurrently(approve_by(@approver, MULTI_FIRST),
                            approve_by(@approver, MULTI_FIRST), request: request)

    assert_equal 1, outcomes.count(true)
    assert_equal MULTI_SECOND, request.reload.current_step_position
  end

  test "委任を受けた利用者の二重送信でも成立するのは 1 件だけ" do
    request = multi_step_request
    delegate = create_user("delegate@example.com", role: "member")
    @organization.approval_delegations.create!(delegator: @first_approver, delegate: delegate,
                                               starts_on: Date.current)

    outcomes = concurrently(approve_by(delegate, MULTI_FIRST),
                            approve_by(delegate, MULTI_FIRST), request: request)

    assert_equal 1, outcomes.count(true)
    assert_equal MULTI_SECOND, request.reload.current_step_position
  end

  test "代理での決裁は、通した段と代理元を履歴へ残す" do
    request = multi_step_request
    delegate = create_user("delegate@example.com", role: "member")
    @organization.approval_delegations.create!(delegator: @first_approver, delegate: delegate,
                                               starts_on: Date.current)

    concurrently(approve_by(delegate, MULTI_FIRST), approve_by(delegate, MULTI_FIRST), request: request)

    activity = request.request_activities.where(action: "approved").sole

    assert_equal MULTI_FIRST, activity.step_position
    assert_equal delegate, activity.actor
    assert_equal @first_approver, activity.on_behalf_of
  end

  test "成立した決裁だけが段の承認として残る" do
    request = multi_step_request

    concurrently(approve_by(@first_approver, MULTI_FIRST),
                 approve_by(@first_approver, MULTI_FIRST), request: request)

    approved = request.request_approval_steps.approved.sole

    assert_equal MULTI_FIRST, approved.position
    assert_equal @first_approver, approved.approver
    assert_not_nil approved.approved_at
  end

  test "承認と差し戻しが同じ段へ同時に届いても成立するのは片方だけ" do
    request = multi_step_request

    outcomes = concurrently(approve_by(@first_approver, MULTI_FIRST),
                            return_by(@first_approver, MULTI_FIRST), request: request)

    assert_equal 1, outcomes.count(true)
    assert_equal 1, request.request_activities.where(action: %w[approved returned]).count
  end

  # 段 2 の担当が、段 1 を待っているあいだに用意した要求。
  #
  # 段の位置だけで照らすと、段 1 の承認が先に成立した直後にこの要求が通り、
  # ひとつの初期状態から 2 段進む。段 2 の判断が、段 1 の結果を前提にしていない。
  test "先の段を指して先に用意した要求は、段が進んだあとでも成立しない" do
    request = multi_step_request
    ahead = state_token(request, @second_approver)

    assert approve_by(@first_approver, MULTI_FIRST).call(request)
    assert_not request.reload.approve(actor: @second_approver, expected_step_position: MULTI_SECOND,
                                      state_token: ahead)

    assert_equal MULTI_SECOND, request.reload.current_step_position
    assert_equal 1, request.request_activities.where(action: "approved").count
  end

  # すべての段を担当する利用者は、占有のなかの立場の判定を必ず通る。
  # 送り直しを止められるのは、状態に結び付いた値だけである。
  test "同じ値を段の位置だけ変えて送り直しても成立しない" do
    request = multi_step_request
    token = state_token(request, @approver)

    assert request.approve(actor: @approver, expected_step_position: MULTI_FIRST, state_token: token)
    assert_not request.reload.approve(actor: @approver, expected_step_position: MULTI_SECOND,
                                      state_token: token)

    assert_equal MULTI_SECOND, request.reload.current_step_position
  end

  # 差し戻して再提出すると、待っている段は 1 段目へ戻る。位置は同じ値になるが、
  # 申請の内容は変わっている。古い画面からの承認を通してはならない。
  test "差し戻して再提出したあと、前の提出のときの要求は成立しない" do
    request = multi_step_request
    before_return = state_token(request, @first_approver)

    assert request.return_to_applicant(actor: @first_approver, expected_step_position: MULTI_FIRST)
    assert request.reload.submit(actor: @applicant)
    assert_equal MULTI_FIRST, request.reload.current_step_position

    assert_not request.approve(actor: @first_approver, expected_step_position: MULTI_FIRST,
                               state_token: before_return)
    assert request.reload.approve(actor: @first_approver, expected_step_position: MULTI_FIRST,
                                  state_token: state_token(request, @first_approver))
  end

  # 制御部が渡すのは、要求に入っていた値そのものである。無い場合は nil になる。
  # 模型の呼び口は指定が無ければ自分で作るため、ここは決裁の単位を直に呼ぶ。
  test "改ざんした値、別の利用者の値、無い値では成立しない" do
    request = multi_step_request
    valid = state_token(request, @first_approver)

    [ nil, "", "#{valid}x", state_token(request, @second_approver) ].each do |token|
      result = RequestDecision.call(request: request.reload, actor: @first_approver, decision: :approve,
                                    expected_step_position: MULTI_FIRST, state_token: token)

      assert_equal :stale, result.outcome, "#{token.inspect} で成立しました"
    end

    assert_equal MULTI_FIRST, request.reload.current_step_position
    assert_equal 0, request.request_activities.where(action: "approved").count
  end

  test "期限を過ぎた値では成立しない" do
    request = multi_step_request
    token = state_token(request, @first_approver)

    travel RequestDecisionToken::EXPIRES_IN + 1.minute do
      assert_not request.reload.approve(actor: @first_approver, expected_step_position: MULTI_FIRST,
                                        state_token: token)
    end

    assert_equal MULTI_FIRST, request.reload.current_step_position
  end

  # 記録のどれかで失敗したときに、その手前までが残ってはならない。
  #
  # 失敗は履歴の作成で起こす。申請の更新と段の印のあとに来るためである。
  # 監査はさらにそのあとに書くため、ここで落ちれば監査も残らない。
  # 実際に到達し得る失敗で確かめる。差し替えを持ち込むと、確かめているのが
  # 経路そのものなのか差し替えなのかが分からなくなる。
  test "記録の途中で失敗すると、状態も段の印も戻る" do
    request = multi_step_request

    assert_no_difference [ -> { RequestActivity.count }, -> { AuditEvent.count },
                           -> { Notification.count }, -> { enqueued_jobs.size } ] do
      assert_raises(ActiveRecord::RecordInvalid) do
        request.approve(actor: @first_approver, comment: too_long_comment,
                        expected_step_position: MULTI_FIRST,
                        state_token: state_token(request, @first_approver))
      end
    end

    request.reload

    assert_equal "pending", request.status
    assert_equal MULTI_FIRST, request.current_step_position
    assert_nil request.decided_at
    assert_empty request.request_approval_steps.approved
  end

  test "差し戻しでも、記録の途中で失敗すれば戻る" do
    request = multi_step_request

    assert_no_difference [ -> { RequestActivity.count }, -> { AuditEvent.count },
                           -> { Notification.count }, -> { enqueued_jobs.size } ] do
      assert_raises(ActiveRecord::RecordInvalid) do
        request.return_to_applicant(actor: @first_approver, comment: too_long_comment,
                                    expected_step_position: MULTI_FIRST,
                                    state_token: state_token(request, @first_approver))
      end
    end

    request.reload

    assert_equal "pending", request.status
    assert_nil request.decided_at
  end

  # 画面を開いたあとに終端の状態まで進んだ場合も、古い要求であることは変わらない。
  # 状態の確認を先に置くと、ここだけが競合ではなく一般の失敗として返る。
  test "承認済みになったあとの古い要求は競合として拒む" do
    assert_equal :stale, outcome_of_stale_request { |request| approve_all_steps(request) }
  end

  test "差し戻されたあとの古い要求は競合として拒む" do
    assert_equal :stale, outcome_of_stale_request { |request|
      request.return_to_applicant(actor: @first_approver)
    }
  end

  test "取り下げられたあとの古い要求は競合として拒む" do
    assert_equal :stale, outcome_of_stale_request { |request| request.withdraw(actor: @applicant) }
  end

  # 立場の判定は、制御部の参照範囲に頼らず、この経路だけで完結させる。
  test "別の組織の管理者は決裁できない" do
    request = multi_step_request
    outsider = create_isolated_organization(name: "別の組織", code: "other-org-decision")
    intruder = outsider.users.create!(name: "外", email_address: "outside@example.com",
                                      password: "a-long-secret-value", role: "administrator")

    result = RequestDecision.call(request: request, actor: intruder, decision: :approve,
                                  expected_step_position: MULTI_FIRST, state_token: nil)

    assert_equal :unauthorized, result.outcome
    assert_equal "pending", request.reload.status
    assert_equal 0, request.request_activities.where(action: "approved").count
  ensure
    discard_organization(outsider)
  end

  test "無効にした担当者は決裁できない" do
    request = multi_step_request
    token = state_token(request, @first_approver)
    @first_approver.update!(deactivated_at: Time.current)

    result = RequestDecision.call(request: request.reload, actor: @first_approver, decision: :approve,
                                  expected_step_position: MULTI_FIRST, state_token: token)

    assert_equal :unauthorized, result.outcome
    assert_equal MULTI_FIRST, request.reload.current_step_position
  end

  # 担当でないことは、見ていた状態より先に伝える。担当外へ競合を返すと、
  # 待てば通ると読める。
  test "担当でない利用者は、値を持たなくても立場として拒む" do
    request = multi_step_request

    result = RequestDecision.call(request: request, actor: @second_approver, decision: :approve,
                                  expected_step_position: MULTI_FIRST, state_token: nil)

    assert_equal :unauthorized, result.outcome
  end

  # 外側の確定を待たずに知らせると、戻された処理の通知だけが残る。
  test "外側の確定より前には通知も送信も作らない" do
    request = multi_step_request
    notifications = Notification.count
    jobs = enqueued_jobs.size

    ActiveRecord::Base.transaction do
      assert approve_by(@first_approver, MULTI_FIRST).call(request)

      assert_equal notifications, Notification.count, "確定の前に通知が作られました"
      assert_equal jobs, enqueued_jobs.size, "確定の前に送信が積まれました"
    end

    assert_equal notifications + 1, Notification.count
  end

  test "外側が戻されると、決裁も通知も送信も残らない" do
    request = multi_step_request

    assert_no_difference [ -> { RequestActivity.count }, -> { AuditEvent.count },
                           -> { Notification.count }, -> { enqueued_jobs.size } ] do
      ActiveRecord::Base.transaction do
        assert approve_by(@first_approver, MULTI_FIRST).call(request)
        raise ActiveRecord::Rollback
      end
    end

    assert_equal MULTI_FIRST, request.reload.current_step_position
  end

  # 同じ 1 つの値を、別々の接続から同時に送る。
  # それぞれが自分で値を作ると、同じ値の送り直しを確かめたことにならない。
  test "同じ値を共有した同時の二重送信でも成立は 1 件だけ" do
    request = multi_step_request
    shared = state_token(request, @first_approver)
    send_shared = approve_with(@first_approver, MULTI_FIRST, shared)

    outcomes = concurrently(send_shared, send_shared, request: request)

    assert_equal 1, outcomes.count(true)
    assert_equal MULTI_SECOND, request.reload.current_step_position
    assert_equal 1, request.request_activities.where(action: "approved").count
    assert_equal 1, request.request_approval_steps.approved.count
    assert_equal 1, AuditEvent.where(organization: @organization, action: "request_approved").count
  end

  # 監査の記録そのものが失敗した場合も、その手前までが残ってはならない。
  # 監査だけを後ろへ移した変更を、このテストが止める。
  test "監査の記録が失敗すると、状態も段の印も履歴も戻る" do
    request = multi_step_request

    assert_no_difference [ -> { RequestActivity.count }, -> { AuditEvent.count },
                           -> { Notification.count }, -> { enqueued_jobs.size } ] do
      assert_raises(ActiveRecord::RecordInvalid) do
        failing_audit { approve_by(@first_approver, MULTI_FIRST).call(request) }
      end
    end

    request.reload

    assert_equal "pending", request.status
    assert_equal MULTI_FIRST, request.current_step_position
    assert_nil request.decided_at
    assert_empty request.request_approval_steps.approved
  end

  test "差し戻しでも、監査の記録が失敗すれば戻る" do
    request = multi_step_request

    assert_no_difference [ -> { RequestActivity.count }, -> { AuditEvent.count },
                           -> { Notification.count }, -> { enqueued_jobs.size } ] do
      assert_raises(ActiveRecord::RecordInvalid) do
        failing_audit { return_by(@first_approver, MULTI_FIRST).call(request) }
      end
    end

    request.reload

    assert_equal "pending", request.status
    assert_nil request.decided_at
  end

  # 時計の分解能に頼らない。時刻を止めたまま差し戻し、修正、再提出まで進めても、
  # 前の提出のときの要求は通ってはならない。
  test "時刻が同じでも、差し戻して再提出したあとの古い要求は成立しない" do
    request = multi_step_request

    travel_to Time.current do
      # 値を作る前に、止めた時刻で一度書き換えておく。そうしないと、更新の時刻は
      # 止める前のままになり、時計に頼った実装でも差が出てしまう。
      request.reload.update!(title: "止めた時刻での申請")

      stale = state_token(request.reload, @first_approver)

      assert request.reload.return_to_applicant(actor: @first_approver)
      assert request.reload.update!(title: "直した申請")
      assert request.reload.submit(actor: @applicant)
      assert_equal MULTI_FIRST, request.reload.current_step_position

      result = RequestDecision.call(request: request.reload, actor: @first_approver, decision: :approve,
                                    expected_step_position: MULTI_FIRST, state_token: stale)

      assert_equal :stale, result.outcome
      assert request.reload.approve(actor: @first_approver, expected_step_position: MULTI_FIRST,
                                    state_token: state_token(request, @first_approver))
    end
  end

  # 呼び出しのときに読んだ利用者の写しは、そのあいだに古くなる。
  test "読み込んだあとに無効にされた利用者は、手元の写しでも決裁できない" do
    request = multi_step_request
    stale_actor = User.find(@first_approver.id)
    token = state_token(request, stale_actor)

    User.find(@first_approver.id).update!(deactivated_at: Time.current)

    result = RequestDecision.call(request: request.reload, actor: stale_actor, decision: :approve,
                                  expected_step_position: MULTI_FIRST, state_token: token)

    assert_equal :unauthorized, result.outcome
    assert_equal MULTI_FIRST, request.reload.current_step_position
  end

  test "読み込んだあとに立場を落とされた管理者は、手元の写しでも決裁できない" do
    request = multi_step_request
    approve_by(@first_approver, MULTI_FIRST).call(request)
    approve_by(@second_approver, MULTI_SECOND).call(request.reload)

    # 組織には利用中の管理者が 1 人は要る。落とす相手とは別に立てておく。
    create_user("keeper@example.com", role: "administrator")

    stale_actor = User.find(@approver.id)
    token = state_token(request, stale_actor)
    User.find(@approver.id).update!(role: "member")

    result = RequestDecision.call(request: request.reload, actor: stale_actor, decision: :approve,
                                  expected_step_position: MULTI_LAST, state_token: token)

    assert_equal :unauthorized, result.outcome
    assert_equal "pending", request.reload.status
  end

  # 立場と代理元を別々に解くと、そのあいだに委任が変わったときに食い違う。
  test "委任が取り消されたあとは、代理での決裁も成立しない" do
    request = multi_step_request
    delegate = create_user("revoked@example.com", role: "member")
    delegation = @organization.approval_delegations.create!(delegator: @first_approver, delegate: delegate,
                                                           starts_on: Date.current)
    token = state_token(request, delegate)

    delegation.destroy!

    result = RequestDecision.call(request: request.reload, actor: delegate, decision: :approve,
                                  expected_step_position: MULTI_FIRST, state_token: token)

    assert_equal :unauthorized, result.outcome
    assert_equal MULTI_FIRST, request.reload.current_step_position
  end

  # 確定したあとの知らせに失敗しても、決裁の結果は変えない。
  # 変えると、画面には失敗が出るのに保存されているのは決裁済み、という
  # 今回直している食い違いが、通知の側から戻る。
  test "確定のあとの通知の記録に失敗しても、決裁は成立したままになる" do
    request = multi_step_request

    reported = reporting_while(Notification, :deliver_to_all) do
      assert approve_by(@first_approver, MULTI_FIRST).call(request)
    end

    assert_equal MULTI_SECOND, request.reload.current_step_position
    assert_equal 1, request.request_activities.where(action: "approved").count
    assert_equal 1, AuditEvent.where(organization: @organization, action: "request_approved").count
    assert_reported reported, request
  end

  test "確定のあとのメールの投入に失敗しても、決裁は成立したままになる" do
    request = multi_step_request
    approve_by(@first_approver, MULTI_FIRST).call(request)
    approve_by(@second_approver, MULTI_SECOND).call(request.reload)

    reported = reporting_while(Notification, :deliver) do
      assert approve_by(@approver, MULTI_LAST).call(request.reload)
    end

    assert_equal "approved", request.reload.status
    assert_not_nil request.decided_at
    assert_reported reported, request
  end

  test "確定のあとの外部への送信に失敗しても、決裁は成立したままになる" do
    request = multi_step_request

    reported = reporting_while(Notification, :publish) do
      assert request.reload.return_to_applicant(actor: @first_approver,
                                                expected_step_position: MULTI_FIRST)
    end

    assert_equal "returned", request.reload.status
    assert_equal 1, request.request_activities.where(action: "returned").count
    assert_reported reported, request
  end

  # 委任は担当を移さない。委任元の立場が消えたら、代理の権限も消える。
  test "委任元を無効にすると、代理での決裁も承認待ちの一覧も消える" do
    request = multi_step_request
    delegate = delegate_of(@first_approver)

    @first_approver.update!(deactivated_at: Time.current)

    result = RequestDecision.call(request: request.reload, actor: delegate, decision: :approve,
                                  expected_step_position: MULTI_FIRST,
                                  state_token: state_token(request, delegate))

    assert_equal :unauthorized, result.outcome
    assert_not Request.awaiting_decision_by(delegate).exists?(id: request.id)
    assert_equal MULTI_FIRST, request.reload.current_step_position
    assert_equal 0, request.request_activities.where(action: "approved").count
  end

  test "委任元の所属が外れると、代理での決裁も承認待ちの一覧も消える" do
    request = multi_step_request
    delegate = delegate_of(@first_approver)

    @first_approver.memberships.destroy_all

    result = RequestDecision.call(request: request.reload, actor: delegate, decision: :approve,
                                  expected_step_position: MULTI_FIRST,
                                  state_token: state_token(request, delegate))

    assert_equal :unauthorized, result.outcome
    assert_not Request.awaiting_decision_by(delegate).exists?(id: request.id)
  end

  test "委任元が管理者でなくなると、管理者の段を代理で通せない" do
    create_user("keeper2@example.com", role: "administrator")
    request = multi_step_request
    approve_by(@first_approver, MULTI_FIRST).call(request)
    approve_by(@second_approver, MULTI_SECOND).call(request.reload)
    delegate = delegate_of(@approver)

    @approver.update!(role: "member")

    result = RequestDecision.call(request: request.reload, actor: delegate, decision: :approve,
                                  expected_step_position: MULTI_LAST,
                                  state_token: state_token(request, delegate))

    assert_equal :unauthorized, result.outcome
    assert_equal "pending", request.reload.status
  end

  test "有効な委任では、決裁も承認待ちの一覧も通知の対象も一致する" do
    request = multi_step_request
    delegate = delegate_of(@first_approver)

    assert Request.awaiting_decision_by(delegate).exists?(id: request.id)
    assert request.reload.approvers.exists?(id: delegate.id)
    assert request.reload.approve(actor: delegate, expected_step_position: MULTI_FIRST,
                                  state_token: state_token(request, delegate))

    activity = request.request_activities.where(action: "approved").sole

    assert_equal delegate, activity.actor
    assert_equal @first_approver, activity.on_behalf_of
  end

  test "委任の取り消しと代理での決裁が競合しても、片方だけが成立する" do
    request = multi_step_request
    delegate = delegate_of(@first_approver)
    token = state_token(request, delegate)

    outcomes = concurrently(
      ->(target) { target.approve(actor: delegate, expected_step_position: MULTI_FIRST, state_token: token) },
      ->(_target) { ApprovalDelegation.where(delegate_id: delegate.id).destroy_all.any? },
      request: request
    )

    decided = outcomes.first

    assert_equal decided, request.reload.current_step_position == MULTI_SECOND
    assert_equal(decided ? 1 : 0, request.request_activities.where(action: "approved").count)
  end

  test "無効にした委任元を戻すと、期間内の委任は再び使える" do
    request = multi_step_request
    delegate = delegate_of(@first_approver)

    @first_approver.update!(deactivated_at: Time.current)
    @first_approver.update!(deactivated_at: nil)

    assert request.reload.approve(actor: delegate, expected_step_position: MULTI_FIRST,
                                  state_token: state_token(request, delegate))
  end

  test "許可されていない決裁の種類では何も変わらない" do
    request = multi_step_request

    result = RequestDecision.call(request: request, actor: @first_approver, decision: :cancel,
                                  expected_step_position: MULTI_FIRST,
                                  state_token: state_token(request, @first_approver))

    assert_equal :invalid_decision, result.outcome
    assert_equal "pending", request.reload.status
    assert_equal MULTI_FIRST, request.current_step_position
    assert_equal 0, request.request_activities.where(action: %w[approved returned]).count
  end

  # 後片付けが 1 件でも取りこぼすと、組織が残る。残った組織は次の実行の
  # 作成を識別子の重複で失敗させ、さらに連番の次の値を占めることで、
  # 無関係なテストの採番まで巻き込む。
  test "後片付けは読み込んだあとに増えた記録も取り除く" do
    @organization.users.load
    @organization.departments.load
    create_user("late@example.com", role: "member")
    @organization.departments.create!(name: "経理部", code: "accounting")

    discard_organization(@organization)

    assert_nil Organization.find_by(code: ORGANIZATION_CODE)
    assert_empty User.where(organization_id: @organization.id)
    assert_empty Department.where(organization_id: @organization.id)
    assert_empty Request.where(organization_id: @organization.id)
  end

  private
    def create_user(email_address, role:)
      @organization.users.create!(
        name: email_address,
        email_address: email_address,
        password: "a-long-secret-value",
        role: role
      )
    end

    def create_request(status:, submitted_at: nil)
      @organization.requests.create!(
        request_type: @request_type,
        applicant: @applicant,
        title: "#{status} の申請",
        status: status,
        submitted_at: submitted_at
      )
    end

    def approve
      ->(request) { request.approve(actor: @approver, comment: DECISION_COMMENTS.fetch("approved")) }
    end

    # 画面が持ち帰る、いま見えている状態の値。
    def state_token(request, actor)
      request.reload.decision_state_token_for(actor)
    end

    # 履歴の作成を必ず失敗させる長さ。上限は 2,000 文字である。
    def too_long_comment = "あ" * 2_001

    # 画面を開いたあとに状態が変わった場合の結果。
    #
    # 送るのは、開いたときに見えていた段である。いまの段ではない。
    def outcome_of_stale_request
      request = multi_step_request
      stale = state_token(request, @first_approver)

      yield request

      RequestDecision.call(request: request.reload, actor: @first_approver, decision: :approve,
                           expected_step_position: MULTI_FIRST, state_token: stale).outcome
    end

    # 決められた値を渡す決裁。同じ値を共有した送り直しを確かめるために使う。
    def approve_with(actor, position, token)
      lambda do |request|
        request.approve(actor: actor, comment: DECISION_COMMENTS.fetch("approved"),
                        expected_step_position: position, state_token: token)
      end
    end

    # 最後の段まで通す。終端の状態を作るために使う。
    def approve_all_steps(request)
      approve_by(@first_approver, MULTI_FIRST).call(request)
      approve_by(@second_approver, MULTI_SECOND).call(request.reload)
      approve_by(@approver, MULTI_LAST).call(request.reload)
    end

    # 指定した処理だけを失敗させる。実際の構成は壊さずに戻す。
    def failing(target, name)
      original = target.method(name)
      target.define_singleton_method(name) { |**| raise "知らせに失敗しました" }
      yield
    ensure
      target.define_singleton_method(name, original)
    end

    # 失敗させたあいだに、この決裁として報告された内容を集める。
    #
    # 他の層も報告し得るため、件数は決裁の文脈に一致するものだけを数える。
    def reporting_while(target, name, &block)
      collected = []
      subscriber = ErrorCollector.new(collected)
      Rails.error.subscribe(subscriber)

      failing(target, name, &block)

      collected
    ensure
      Rails.error.unsubscribe(subscriber)
    end

    def assert_reported(collected, request)
      decision = collected.select { |entry| entry[:context][:announce] == "request_decision" }

      assert_equal 1, decision.size, "決裁としての報告が 1 件ではありません"
      assert decision.sole[:handled], "処理済みとして報告されていません"
      assert_equal request.id, decision.sole[:context][:request_id]
      assert_equal %i[announce request_id].sort, decision.sole[:context].keys.sort,
                   "決裁の内容が文脈へ入っています"
    end

    # 委任を受けた利用者を作る。
    def delegate_of(delegator)
      delegate = create_user("delegate-#{delegator.id}@example.com", role: "member")
      @organization.approval_delegations.create!(delegator: delegator, delegate: delegate,
                                                 starts_on: Date.current)
      delegate
    end

    # 報告を集める受け手。差し替えではなく、用意されている仕組みを使う。
    class ErrorCollector
      def initialize(collected) = @collected = collected

      def report(error, handled:, severity:, context:, source: nil)
        @collected << { error: error, handled: handled, severity: severity, context: context }
      end
    end

    # 監査の記録だけを失敗させる。実際の構成は壊さずに戻す。
    #
    # 元の定義を控えてから差し替える。消すだけで戻すと、元から特異メソッドで
    # あるため、この定義そのものが失われる。
    def failing_audit
      original = AuditEvent.method(:record)
      AuditEvent.define_singleton_method(:record) { |**| raise ActiveRecord::RecordInvalid, AuditEvent.new }
      yield
    ensure
      AuditEvent.define_singleton_method(:record, original)
    end

    # 期待する段を指定した決裁。画面からの決裁と同じ形にする。
    def approve_by(actor, position)
      lambda do |request|
        request.approve(actor: actor, comment: DECISION_COMMENTS.fetch("approved"),
                        expected_step_position: position)
      end
    end

    def return_by(actor, position)
      lambda do |request|
        request.return_to_applicant(actor: actor, comment: DECISION_COMMENTS.fetch("returned"),
                                    expected_step_position: position)
      end
    end

    # 段ごとに担当を分けた 3 段の申請を、提出済みで作る。
    #
    # 提出を経ることで、経路が申請へ写る。写した経路を持たない申請では、
    # 段への承認の印を残す先が無く、確かめたい記録が現れない。
    def multi_step_request
      second_department = @organization.departments.create!(name: "開発部", code: "development")
      @first_approver = create_user("first@example.com", role: "member")
      @first_approver.memberships.create!(department: @department)
      @second_approver = create_user("second@example.com", role: "member")
      @second_approver.memberships.create!(department: second_department)

      request_type = @organization.request_types.create!(
        name: "多段の申請", code: "multi-step",
        approval_steps_attributes: [
          { position: MULTI_FIRST, approver_department_id: @department.id },
          { position: MULTI_SECOND, approver_department_id: second_department.id },
          { position: MULTI_LAST, approver_department_id: nil }
        ]
      )

      request = @organization.requests.create!(request_type: request_type, applicant: @applicant,
                                               title: "多段の申請")
      request.submit(actor: @applicant)
      request
    end

    def return_to_applicant
      ->(request) { request.return_to_applicant(actor: @approver, comment: DECISION_COMMENTS.fetch("returned")) }
    end

    def withdraw
      ->(request) { request.withdraw(actor: @applicant) }
    end

    def submit
      ->(request) { request.submit(actor: @applicant) }
    end

    def decision_activities
      @request.request_activities.where(action: %w[approved returned])
    end

    def decision_notifications
      Notification.where(user: @applicant, subject: @request, event: %w[request_approved request_returned])
    end

    # 積まれた送信のうち、出来事の名前だけを取り出す。
    # 件数だけでは、成立していない側の出来事が混ざっていても気付けない。
    def enqueued_webhook_events
      enqueued_jobs.select { |job| job[:job] == DeliverWebhookJob }.map { |job| job[:args].second }
    end

    # 両方の thread が申請を読み終えてから、同時に処理へ入る。
    # 待ち時間で揃えると、遅い環境で先後がずれて確認にならない。
    #
    # 準備の成否は必ず ready へ 1 件通知する。通知しないまま終わる thread が
    # あると、待つ側が理由の分からないまま止まる。
    #
    # thread の中で起きた例外は、結果を返す前にここで失敗として扱う。
    # 呼出側へ渡してしまうと、副作用の件数だけを見るテストが見逃す。
    def concurrently(*operations, request: @request)
      ready = Queue.new
      start = Queue.new
      outcomes = Queue.new
      threads = []

      operations.each do |operation|
        threads << Thread.new do
          prepared = false

          begin
            ActiveRecord::Base.connection_pool.with_connection do
              target = Request.find(request.id)
              prepared = true
              ready << :ready
              start.pop
              outcomes << operation.call(target)
            end
          rescue StandardError => error
            outcomes << error
            ready << error unless prepared
          end
        end
      end

      Timeout.timeout(PREPARATION_TIMEOUT) { operations.each { ready.pop } }
      operations.each { start << true }
      threads.each { |thread| assert thread.join(COMPLETION_TIMEOUT), "処理が終わりませんでした" }

      results = Timeout.timeout(OUTCOME_TIMEOUT) { operations.map { outcomes.pop } }
      errors = results.grep(Exception)

      assert_empty errors, errors.map { |error| "#{error.class}: #{error.message}" }.join("\n")

      results
    ensure
      # 異常終了では、開始の合図を待ったままの thread が残る。
      # 解放しても終わらないものだけを止め、次のテストへ持ち越さない。
      threads.select(&:alive?).each { start << true }
      threads.each { |thread| thread.kill unless thread.join(CLEANUP_TIMEOUT) }
    end

    # SQL 全体の一致は実装の書き方に縛られるため、対象と種類だけを見る。
    def locking_statements
      statements = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        statements << payload[:sql]
      end

      yield

      statements.grep(/FOR UPDATE/i).grep(/requests/i)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
end
