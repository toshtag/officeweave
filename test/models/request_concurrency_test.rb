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

  # 後片付けが 1 件でも取りこぼすと、組織が残る。残った組織は次の実行の
  # 作成を識別子の重複で失敗させ、さらに連番の次の値を占めることで、
  # 無関係なテストの採番まで巻き込む。
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
  # 段 2 の担当が段 2 を指した要求は、ここでは扱わない。占有した時点で段 2 に
  # なっていれば成立し、なっていなければ競合になる。どちらの結果でも、段は
  # その段の担当だけが通す。段を飛ばす形にはならない。
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
