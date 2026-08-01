require "test_helper"
require "timeout"

# 利用者の無効化と token の発行が同時に走った場合の確認。
#
# 発行の前に有効かどうかを見るだけでは、見た時点と INSERT の間に
# 無効化が成立し得る。それを確かめるには別々の接続から同時に実行する
# 必要があるため、このクラスだけトランザクションで囲む既定を外す。
class ApiTokenConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  # 待機はすべて上限を持たせる。退行を CI の停止ではなく失敗として受け取るため。
  PREPARATION_TIMEOUT = 10
  COMPLETION_TIMEOUT = 30
  OUTCOME_TIMEOUT = 5
  CLEANUP_TIMEOUT = 5

  setup do
    @organization = Organization.create!(name: "token の同時実行の確認", code: "api-token-concurrency")
    # 無効化を最後の管理者の契約で止めないため、管理者は別に残す。
    create_user("keeper@example.com", role: "administrator")
    @user = create_user("holder@example.com")
  end

  teardown do
    @organization.users.destroy_all
    @organization.destroy
  end

  test "発行が先に確定すると無効化がその token を失効させる" do
    token = build_token

    in_order(first: -> { token.save! }, second: -> { User.find(@user.id).deactivate! })

    assert_not_predicate @user.reload, :active?
    assert_predicate token.reload, :revoked?
    assert_nil ApiToken.authenticate(token.token)
    assert_empty @user.api_tokens.active
  end

  test "無効化が先に確定すると発行を拒む" do
    token = build_token

    in_order(first: -> { User.find(@user.id).deactivate! }, second: -> { token.save })

    assert_not_predicate @user.reload, :active?
    assert_predicate token, :new_record?
    assert_includes token.errors.details[:user], { error: :inactive }
    assert_empty @user.api_tokens
  end

  # 先後を固定しない実行。どちらが勝っても、無効な利用者に
  # 有効な token が残ってはならない。
  test "無効化と発行が同時でも有効な token は残らない" do
    outcomes = deactivate_and_issue_concurrently

    assert_empty outcomes.values.grep(Exception)
    assert_not_predicate @user.reload, :active?
    assert_empty @user.api_tokens.active

    token = outcomes.fetch(:issue)

    if token.persisted?
      assert_predicate token.reload, :revoked?
      assert_nil ApiToken.authenticate(token.token)
    else
      assert_includes token.errors.details[:user], { error: :inactive }
      assert_empty @user.api_tokens
    end
  end

  # 有効かどうかの検査だけへ戻ると、並行実行はすり抜けても気付けない。
  # 行ロックが消えたことを、並行の結果とは別に見る。
  test "token の発行では利用者の行をロックする" do
    statements = locking_statements { @organization.api_tokens.create!(user: @user, name: "ロックの確認") }

    assert_predicate statements, :any?
  end

  # 準備の段階で失敗した thread は、開始の合図を受け取らないまま終わる。
  # そこで待ち続けると、退行が明確な失敗ではなく CI の停止として現れる。
  test "準備の段階で失敗しても待ち続けず理由を返す" do
    outcomes = Timeout.timeout(5) do
      concurrently(
        missing: { prepare: -> { User.find(-1) }, act: ->(user) { user.deactivate! } },
        issue: { prepare: -> { build_token }, act: ->(token) { token.tap(&:save) } }
      )
    end

    assert_equal 2, outcomes.size
    assert_kind_of ActiveRecord::RecordNotFound, outcomes.fetch(:missing)
    assert_predicate outcomes.fetch(:issue), :persisted?
  end

  private
    def create_user(email_address, **attributes)
      @organization.users.create!(
        { name: email_address, email_address: email_address, password: "a-long-secret-value" }.merge(attributes)
      )
    end

    def build_token
      Organization.find(@organization.id).api_tokens.new(user_id: @user.id, name: "同時発行")
    end

    def in_background(&block)
      Thread.new { ActiveRecord::Base.connection_pool.with_connection(&block) }
    end

    # 先に確定させる側が利用者の行を占有したまま、もう一方を開始する。
    # 占有は確定するまで解けないため、待ち時間ではなく順序そのものを固定できる。
    #
    # 後から始めた側が占有へ到達する前に確定した場合も、読み取るのは
    # 確定後の状態であり、確かめたい順序は変わらない。
    def in_order(first:, second:)
      held = Queue.new
      release = Queue.new
      threads = []

      threads << in_background do
        ActiveRecord::Base.transaction do
          first.call
          held << :held
          release.pop
        end
      end

      Timeout.timeout(PREPARATION_TIMEOUT) { held.pop }
      threads << in_background { second.call }
      release << true

      threads.each { |thread| assert thread.join(COMPLETION_TIMEOUT), "処理が終わりませんでした" }
    ensure
      # 異常終了では、確定の合図を待ったままの thread が残る。
      # 解放しても終わらないものだけを止め、次のテストへ持ち越さない。
      release << true if threads.any?(&:alive?)
      threads.each { |thread| thread.kill unless thread.join(CLEANUP_TIMEOUT) }
    end

    def deactivate_and_issue_concurrently
      concurrently(
        deactivation: { prepare: -> { User.find(@user.id) }, act: ->(user) { user.tap(&:deactivate!) } },
        issue: { prepare: -> { build_token }, act: ->(token) { token.tap(&:save) } }
      )
    end

    # 両方の thread が対象を読み終えてから、同時に処理へ入る。
    # 待ち時間で揃えると、遅い環境で先後がずれて確認にならない。
    #
    # 準備の成否は必ず ready へ 1 件通知する。通知しないまま終わる thread が
    # あると、待つ側が理由の分からないまま止まる。
    def concurrently(operations)
      ready = Queue.new
      start = Queue.new
      outcomes = Queue.new
      threads = []

      operations.each do |name, steps|
        threads << Thread.new do
          prepared = false

          begin
            ActiveRecord::Base.connection_pool.with_connection do
              subject = steps[:prepare].call
              prepared = true
              ready << :ready
              start.pop
              outcomes << [ name, steps[:act].call(subject) ]
            end
          rescue StandardError => error
            outcomes << [ name, error ]
            ready << error unless prepared
          end
        end
      end

      Timeout.timeout(PREPARATION_TIMEOUT) { operations.each { ready.pop } }
      operations.each { start << true }
      threads.each { |thread| assert thread.join(COMPLETION_TIMEOUT), "処理が終わりませんでした" }

      Timeout.timeout(OUTCOME_TIMEOUT) { operations.map { outcomes.pop }.to_h }
    ensure
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

      statements.grep(/FOR UPDATE/i).grep(/users/i)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
end
