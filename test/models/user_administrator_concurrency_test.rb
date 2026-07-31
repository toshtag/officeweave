require "test_helper"
require "timeout"

# 管理者を失わせる更新が同時に走った場合の確認。
#
# 件数を数えるだけでは、互いを管理者として観測した 2 件が両方成功しうる。
# それを確かめるには別々の接続から同時に更新する必要があるため、
# このクラスだけトランザクションで囲む既定を外す。
class UserAdministratorConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  # 待機はすべて上限を持たせる。退行を CI の停止ではなく失敗として受け取るため。
  PREPARATION_TIMEOUT = 10
  COMPLETION_TIMEOUT = 30
  OUTCOME_TIMEOUT = 5
  CLEANUP_TIMEOUT = 5

  setup do
    @organization = Organization.create!(name: "同時実行の確認", code: "concurrency-check")
    @first = create_administrator("first@example.com")
    @second = create_administrator("second@example.com")
  end

  teardown do
    @organization.users.destroy_all
    @organization.destroy
  end

  test "同時に降格しても利用中の管理者が 1 人残る" do
    outcomes = demote_concurrently(@first, @second)

    assert_empty outcomes.grep(Exception)
    assert_equal 1, outcomes.count(true)
    assert_equal 1, outcomes.count(false)
    assert_equal 1, @organization.users.active.administrator.count
    assert_equal 1, @organization.users.active.member.count
  end

  test "管理者を失わせる更新では組織の行をロックする" do
    statements = locking_statements { @first.update!(role: "member") }

    assert_predicate statements, :any?
  end

  test "権限と有効状態を変えない更新では組織の行をロックしない" do
    statements = locking_statements { @first.update!(name: "更新後の氏名") }

    assert_empty statements
  end

  # 準備の段階で失敗した thread は、開始の合図を受け取らないまま終わる。
  # そこで待ち続けると、退行が明確な失敗ではなく CI の停止として現れる。
  test "準備の段階で失敗しても待ち続けず理由を返す" do
    missing = User.new(id: -1)

    outcomes = Timeout.timeout(5) { demote_concurrently(@first, missing) }

    assert_equal 2, outcomes.size
    assert_equal 1, outcomes.grep(ActiveRecord::RecordNotFound).size
    assert_equal [ true ], outcomes.grep_v(Exception)
  end

  private
    def create_administrator(email_address)
      @organization.users.create!(
        name: email_address,
        email_address: email_address,
        password: "a-long-secret-value",
        role: "administrator"
      )
    end

    # 両方の thread が対象を読み終えてから、同時に更新へ入る。
    # 待ち時間で揃えると、遅い環境で先後がずれて確認にならない。
    #
    # 準備の成否は必ず ready へ 1 件通知する。通知しないまま終わる thread が
    # あると、待つ側が理由の分からないまま止まる。
    def demote_concurrently(*administrators)
      ready = Queue.new
      start = Queue.new
      outcomes = Queue.new
      threads = []

      administrators.each do |administrator|
        threads << Thread.new do
          prepared = false

          begin
            ActiveRecord::Base.connection_pool.with_connection do
              target = User.find(administrator.id)
              prepared = true
              ready << :ready
              start.pop
              outcomes << target.update(role: "member")
            end
          rescue StandardError => error
            outcomes << error
            ready << error unless prepared
          end
        end
      end

      Timeout.timeout(PREPARATION_TIMEOUT) { administrators.each { ready.pop } }
      administrators.each { start << true }
      threads.each { |thread| assert thread.join(COMPLETION_TIMEOUT), "更新が終わりませんでした" }

      Timeout.timeout(OUTCOME_TIMEOUT) { administrators.map { outcomes.pop } }
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

      statements.grep(/FOR UPDATE/i).grep(/organizations/i)
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
end
