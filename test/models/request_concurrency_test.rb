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

  self.use_transactional_tests = false

  # 決裁ごとに違う理由を渡す。敗れた側の理由が履歴へ残っていないことを見るため。
  DECISION_COMMENTS = { "approved" => "承認の理由", "returned" => "差し戻しの理由" }.freeze

  # 待機はすべて上限を持たせる。退行を CI の停止ではなく失敗として受け取るため。
  PREPARATION_TIMEOUT = 10
  COMPLETION_TIMEOUT = 30
  OUTCOME_TIMEOUT = 5
  CLEANUP_TIMEOUT = 5

  setup do
    @organization = Organization.create!(name: "申請の同時実行", code: "request-concurrency")
    @department = @organization.departments.create!(name: "総務部", code: "general-affairs")
    @applicant = create_user("applicant@example.com", role: "member")
    @approver = create_user("approver@example.com", role: "administrator")
    @approver.memberships.create!(department: @department)
    @request_type = @organization.request_types.create!(
      name: "休暇届", code: "leave", approver_department: @department
    )
    @endpoint = @organization.webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")
    @request = create_request(status: "pending", submitted_at: 1.day.ago)
  end

  teardown do
    requests = Request.where(organization_id: @organization.id)

    Notification.where(subject_type: "Request", subject_id: requests.select(:id)).delete_all
    RequestActivity.where(request_id: requests.select(:id)).delete_all
    requests.delete_all
    @request_type.destroy
    @endpoint.destroy
    @organization.users.each { |user| user.memberships.delete_all }
    @organization.users.destroy_all
    @department.destroy
    @organization.destroy
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

  private
    def create_user(email_address, role:)
      @organization.users.create!(
        name: email_address,
        email_address: email_address,
        password: "a-secret-value",
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
