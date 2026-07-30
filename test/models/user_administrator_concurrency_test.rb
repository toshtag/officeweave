require "test_helper"

# 管理者を失わせる更新が同時に走った場合の確認。
#
# 件数を数えるだけでは、互いを管理者として観測した 2 件が両方成功しうる。
# それを確かめるには別々の接続から同時に更新する必要があるため、
# このクラスだけトランザクションで囲む既定を外す。
class UserAdministratorConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

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

  private
    def create_administrator(email_address)
      @organization.users.create!(
        name: email_address,
        email_address: email_address,
        password: "a-secret-value",
        role: "administrator"
      )
    end

    # 両方の thread が対象を読み終えてから、同時に更新へ入る。
    # 待ち時間で揃えると、遅い環境で先後がずれて確認にならない。
    def demote_concurrently(*administrators)
      ready = Queue.new
      start = Queue.new
      outcomes = Queue.new

      threads = administrators.map do |administrator|
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            target = User.find(administrator.id)
            ready << true
            start.pop
            outcomes << target.update(role: "member")
          rescue StandardError => error
            outcomes << error
          end
        end
      end

      administrators.each { ready.pop }
      administrators.each { start << true }
      threads.each { |thread| assert thread.join(30), "更新が終わりませんでした" }

      administrators.map { outcomes.pop }
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
