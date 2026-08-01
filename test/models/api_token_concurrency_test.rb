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
    # 無効化が組織の行の占有を通る対象。一般利用者の無効化はそこを通らない。
    @administrator = create_user("target-administrator@example.com", role: "administrator")
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
  #
  # 順序も併せて見る。組織を先に取ることが、管理者の無効化と
  # 循環しないための条件そのものである。
  test "token の発行では組織から利用者の順に行をロックする" do
    statements = sql_statements { @organization.api_tokens.create!(user: @user, name: "ロック順序の確認") }

    organization_index = statements.index { |sql| sql.match?(/organizations/i) && sql.match?(/FOR KEY SHARE/i) }
    user_index = statements.index { |sql| sql.match?(/users/i) && sql.match?(/FOR UPDATE/i) }

    assert_not_nil organization_index, "組織の行を KEY SHARE で取得していません"
    assert_not_nil user_index, "利用者の行を FOR UPDATE で取得していません"
    assert_operator organization_index, :<, user_index
  end

  # 管理者の無効化は、最後の管理者を守るために組織の行を占有してから
  # 利用者を更新する。発行が利用者を先に占有すると、互いの相手を待つ
  # 循環になり、どちらかが Deadlocked で中断される。
  test "管理者の無効化と発行が競合しても行き詰まらない" do
    token = build_token(@administrator)

    outcomes = while_issuance_waits(token) { User.find(@administrator.id).deactivate! }

    assert_empty outcomes.values.compact
    assert_not_predicate @administrator.reload, :active?
    assert_empty @administrator.api_tokens.active
    assert_predicate token, :new_record?
  end

  # 循環の有無は、発行が組織の行を待っている時点の利用者の行で直接見る。
  # 待っている間に利用者の行が空いていれば、発行は利用者を先に取っていない。
  test "発行は利用者より先に組織の行を占有しない" do
    token = build_token(@administrator)

    outcomes = while_issuance_waits(token) { User.lock("FOR UPDATE NOWAIT").find(@administrator.id) }

    assert_nil outcomes.fetch(:holder), "発行が利用者の行を先に占有していました"
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

  # 順序を固定する側にも、結果を呼出側へ返す義務がある。
  # 確定したあとの失敗を取りこぼすと、期待した状態だけが残って成功に見える。
  test "順序を固定した実行で後段の例外を呼出側へ返す" do
    error = assert_raises(RuntimeError) do
      in_order(first: -> { User.find(@user.id) }, second: -> { raise "後段の失敗" })
    end

    assert_equal "後段の失敗", error.message
  end

  # 先に確定させる側が準備の段階で失敗すると、確定の合図は届かない。
  # そこで待ち続けると、理由が上限時間の経過に置き換わる。
  test "順序を固定した実行で準備の失敗を待たずに返す" do
    error = assert_raises(RuntimeError) do
      Timeout.timeout(PREPARATION_TIMEOUT / 2.0) do
        in_order(first: -> { raise "準備の失敗" }, second: -> { raise "後段を開始してはならない" })
      end
    end

    assert_equal "準備の失敗", error.message
  end

  # kill は停止を指示するだけで、終了までは待たない。
  test "終了しない thread は kill のあとに join し直して回収する" do
    blocked = blocked_thread

    remaining = join_or_stop_threads([ blocked ], timeout: 0.01)

    assert_empty remaining
    assert_not_predicate blocked, :alive?
  end

  # Thread#join は、例外で終わった thread の例外を呼出側へ送出し直す。
  # 回収の途中でそれを浴びると、残りの thread が回収されないまま残る。
  test "例外で終わった thread があっても残りの回収を続ける" do
    # 意図した例外であり、標準エラーへの報告は要らない。
    failing = Thread.new do
      Thread.current.report_on_exception = false
      raise "worker の失敗"
    end
    blocked = blocked_thread

    remaining = join_or_stop_threads([ failing, blocked ], timeout: 0.01)

    assert_empty remaining
    assert_not_predicate blocked, :alive?
  end

  private
    def create_user(email_address, **attributes)
      @organization.users.create!(
        { name: email_address, email_address: email_address, password: "a-long-secret-value" }.merge(attributes)
      )
    end

    def build_token(user = @user)
      Organization.find(@organization.id).api_tokens.new(user_id: user.id, name: "同時発行")
    end

    def backend_pid
      ActiveRecord::Base.connection.select_value("SELECT pg_backend_pid()")
    end

    # 実際にロック待ちへ入ったことを、データベースの待ちグラフで確かめる。
    # 固定時間の sleep で代用すると、遅い環境では待つ前に先へ進む。
    def wait_until_blocked(pid)
      Timeout.timeout(PREPARATION_TIMEOUT) do
        loop do
          blockers = ActiveRecord::Base.connection.select_value(
            "SELECT cardinality(pg_blocking_pids(#{Integer(pid)}))"
          )
          break if blockers.to_i.positive?

          Thread.pass
        end
      end
    end

    # 組織の行を占有した状態で発行を始め、発行がロック待ちへ入った時点で
    # block を実行する。管理者の無効化が最初に取る占有を再現し、
    # 先後を待ち時間ではなく待ちグラフの観測で固定する。
    #
    # block は占有を持つ側の接続で実行する。無効化そのものを渡せば循環の
    # 有無を、利用者の行の取得を渡せば占有の順序を、同じ足場で確かめられる。
    def while_issuance_waits(token)
      locked = Queue.new
      release = Queue.new
      pids = Queue.new
      outcomes = Queue.new
      threads = []
      remaining = []
      results = {}

      begin
        threads << in_background do
          collecting(:holder, outcomes) do
            ActiveRecord::Base.transaction do
              Organization.lock.find(@organization.id)
              locked << :locked
              release.pop
              yield
            end
          end
        end

        Timeout.timeout(PREPARATION_TIMEOUT) { locked.pop }

        threads << in_background do
          collecting(:issue, outcomes) do
            pids << backend_pid
            token.save
          end
        end

        wait_until_blocked(Timeout.timeout(PREPARATION_TIMEOUT) { pids.pop })
        release << true

        threads.each { |thread| assert thread.join(COMPLETION_TIMEOUT), "処理が終わりませんでした" }
        results = Timeout.timeout(OUTCOME_TIMEOUT) { %i[holder issue].map { outcomes.pop } }.to_h
      ensure
        release << true if threads.any?(&:alive?)
        remaining = join_or_stop_threads(threads)
      end

      assert_empty remaining, "停止できない thread が残りました"
      results
    end

    def in_background(&block)
      Thread.new { ActiveRecord::Base.connection_pool.with_connection(&block) }
    end

    # 自分からは終わらない thread。固定時間の sleep で待たずに
    # 待機状態へ入れるため、解放されない Queue を使う。
    def blocked_thread
      thread = Thread.new { Queue.new.pop }
      Thread.pass until thread.alive?

      thread
    end

    # thread の中で終わった例外を、呼出側が受け取れる形にして残す。
    # 例外のまま終わらせると、回収のために join し直した側がそれを浴びる。
    # 報告の内容が、回収と報告のどちらを先に書いたかで変わってしまう。
    def collecting(name, outcomes)
      yield
      outcomes << [ name, nil ]
    rescue StandardError => error
      outcomes << [ name, error ]
    end

    # Thread#kill は停止を指示するだけで、終了までは待たない。
    # 指示したあとに join し直さないと、接続を持ったままの thread を
    # 残して teardown の削除へ進み、次のテストが理由の分からない
    # 失敗を受け取ることになる。
    #
    # 2 度目の join でも終わらなかった thread だけを返す。
    # 回収できなかったことを、呼出側が失敗として扱えるようにする。
    def join_or_stop_threads(threads, timeout: CLEANUP_TIMEOUT)
      threads.filter_map do |thread|
        next if join_quietly(thread, timeout)

        thread.kill
        join_quietly(thread, timeout)

        thread if thread.alive?
      end
    end

    # Thread#join は、その thread が例外で終わっていた場合、呼出側へ
    # 送出し直す。回収の途中でそれを浴びると、残りの thread を回収しないまま
    # 抜けることになる。ここは待つことだけを行い、理由の報告は
    # collecting が記録した結果に任せる。
    def join_quietly(thread, timeout)
      thread.join(timeout)
    rescue StandardError
      thread
    end

    # 1 件なら原因をそのまま送出する。複数あるときは、片方だけを
    # 送出して残りを落とさないよう、両方を並べて失敗させる。
    def raise_worker_failures(failures)
      return if failures.empty?
      raise failures.values.first if failures.size == 1

      flunk failures.map { |name, error| "#{name}: #{error.class}: #{error.message}" }.join(" / ")
    end

    # 先に確定させる側が利用者の行を占有したまま、もう一方を開始する。
    # 占有は確定するまで解けないため、待ち時間ではなく順序そのものを固定できる。
    #
    # 後から始めた側が占有へ到達する前に確定した場合も、読み取るのは
    # 確定後の状態であり、確かめたい順序は変わらない。
    def in_order(first:, second:)
      held = Queue.new
      release = Queue.new
      outcomes = Queue.new
      threads = []
      remaining = []
      failures = {}

      begin
        threads << in_background do
          collecting(:first, outcomes) do
            prepared = false

            begin
              ActiveRecord::Base.transaction do
                first.call
                prepared = true
                held << :held
                release.pop
              end
            rescue StandardError
              # 確定の合図を待つ側へ結果を渡してから、収集する側へ送り直す。
              held << :failed unless prepared
              raise
            end
          end
        end

        # 先に確定させる側が準備の段階で失敗した場合、後段には
        # 確かめたい順序が存在しない。開始せず、理由だけを返す。
        prepared = Timeout.timeout(PREPARATION_TIMEOUT) { held.pop } == :held
        started = prepared ? %i[first second] : %i[first]
        threads << in_background { collecting(:second, outcomes) { second.call } } if prepared
        release << true

        threads.each { |thread| assert thread.join(COMPLETION_TIMEOUT), "処理が終わりませんでした" }
        failures = Timeout.timeout(OUTCOME_TIMEOUT) { started.map { outcomes.pop } }.to_h.compact
      ensure
        # 異常終了では、確定の合図を待ったままの thread が残る。
        release << true if threads.any?(&:alive?)
        remaining = join_or_stop_threads(threads)
      end

      assert_empty remaining, "停止できない thread が残りました"
      raise_worker_failures(failures)
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
      remaining = []
      results = nil

      begin
        operations.each do |name, steps|
          threads << in_background do
            prepared = false

            begin
              subject = steps[:prepare].call
              prepared = true
              ready << :ready
              start.pop
              outcomes << [ name, steps[:act].call(subject) ]
            rescue StandardError => error
              outcomes << [ name, error ]
              ready << error unless prepared
            end
          end
        end

        Timeout.timeout(PREPARATION_TIMEOUT) { operations.each { ready.pop } }
        operations.each { start << true }
        threads.each { |thread| assert thread.join(COMPLETION_TIMEOUT), "処理が終わりませんでした" }

        results = Timeout.timeout(OUTCOME_TIMEOUT) { operations.map { outcomes.pop }.to_h }
      ensure
        # 開始の合図を待ったままの thread を解放してから回収する。
        threads.count(&:alive?).times { start << true }
        remaining = join_or_stop_threads(threads)
      end

      assert_empty remaining, "停止できない thread が残りました"
      results
    end

    # SQL 全体の一致は実装の書き方に縛られるため、呼出側では対象と種類、
    # および発行の前後だけを見る。
    def sql_statements
      statements = []
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        statements << payload[:sql]
      end

      yield

      statements
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber)
    end
end
