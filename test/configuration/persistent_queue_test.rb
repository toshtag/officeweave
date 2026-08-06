require "test_helper"
require "yaml"

# 永続キューの構成を固定する。
#
# 設定を間違えても画面は動く。ジョブだけが溜まる、あるいは消える。
# 気付きにくいため、構成そのものを検査で押さえる。
class PersistentQueueTest < ActiveSupport::TestCase
  test "テストではジョブの実行を待たないアダプターを使う" do
    assert_equal :test, Rails.application.config.active_job.queue_adapter
  end

  test "開発と運用では永続キューを使う" do
    %w[development production].each do |environment|
      contents = File.read(Rails.root.join("config/environments/#{environment}.rb"))

      assert_includes contents, "config.active_job.queue_adapter = :solid_queue",
                      "#{environment} で永続キューを使っていない"
      assert_includes contents, "config.solid_queue.connects_to = { database: { writing: :queue } }",
                      "#{environment} でジョブ用データベースへつないでいない"
    end
  end

  test "終わったジョブは残し、失敗したジョブは自動で消さない" do
    %w[development production].each do |environment|
      contents = File.read(Rails.root.join("config/environments/#{environment}.rb"))

      assert_includes contents, "config.solid_queue.preserve_finished_jobs = true"
      assert_includes contents, "config.solid_queue.clear_finished_jobs_after = 1.day"
    end
  end

  # 登録してよいのは、後始末と、時刻の到来だけで成立する状態の変更に限る。
  # 一覧をここへ書き出し、増やす判断を明示的にする。
  test "定期実行には後始末と、時刻の到来で成立する処理だけを登録する" do
    recurring = YAML.safe_load_file(Rails.root.join("config/recurring.yml"), aliases: true)

    assert_equal %w[production], recurring.keys
    assert_equal %w[
      clear_solid_queue_finished_jobs
      delete_expired_sessions
      delete_expired_audit_events
      delete_expired_rate_limit_counters
      report_operational_issues
      publish_scheduled_announcements
    ], recurring["production"].keys
  end

  test "実行の間隔を重ねない" do
    tasks = YAML.safe_load_file(Rails.root.join("config/recurring.yml"), aliases: true).fetch("production")
    minutes = tasks.values.map { |task| task.fetch("schedule") }

    assert_equal minutes.uniq.size, minutes.size, "同じ時刻に複数の定期実行を登録している"
  end

  # お知らせの公開は、日時の到来だけで成立する。誰の操作も待てないため、
  # 定期実行から拾う。
  test "公開待ちのお知らせは登録した名前で呼び出せる" do
    tasks = YAML.safe_load_file(Rails.root.join("config/recurring.yml"), aliases: true).fetch("production")

    assert_equal "PublishScheduledAnnouncementsJob",
                 tasks.dig("publish_scheduled_announcements", "class")
    assert_kind_of Class, PublishScheduledAnnouncementsJob
  end

  test "期限切れセッションの削除は登録した名前で呼び出せる" do
    tasks = YAML.safe_load_file(Rails.root.join("config/recurring.yml"), aliases: true).fetch("production")

    assert_equal "Session.delete_expired", tasks.dig("delete_expired_sessions", "command")
    assert_respond_to Session, :delete_expired
  end

  test "ジョブは primary とは別のデータベースへ置く" do
    databases = database_configuration

    %w[development production].each do |environment|
      configuration = databases.fetch(environment)

      assert configuration.key?("primary"), "#{environment} に primary がない"
      assert configuration.key?("queue"), "#{environment} に queue がない"
      refute_equal configuration.dig("primary", "database"), configuration.dig("queue", "database"),
                   "#{environment} で primary と queue が同じデータベースを指している"
      assert_equal "db/queue_migrate", configuration.dig("queue", "migrations_paths")
    end
  end

  test "開発と運用のジョブ用データベースの既定値が異なる" do
    # 実行中のコンテナは環境変数で名前を与えている。
    # 既定値そのものを確かめるため、いったん外して読み直す。
    databases = without_environment("DATABASE_NAME", "QUEUE_DATABASE_NAME") { database_configuration }

    refute_equal databases.dig("development", "queue", "database"),
                 databases.dig("production", "queue", "database")
    refute_equal databases.dig("development", "primary", "database"),
                 databases.dig("production", "primary", "database")
  end

  test "実行 thread 数はジョブ用データベースの接続数へ収まる" do
    queue = YAML.safe_load(
      ERB.new(File.read(Rails.root.join("config/queue.yml"))).result,
      aliases: true
    )

    worker = queue.dig("production", "workers", 0)

    assert_equal "*", worker["queues"]
    assert_operator worker["threads"].to_i, :>=, 1
    assert_operator worker["processes"].to_i, :>=, 1

    connections = ENV.fetch("QUEUE_DATABASE_CONNECTIONS", 5).to_i
    assert_operator worker["threads"].to_i, :<=, connections - 2,
                    "実行 thread 数が接続数に対して多い"
  end

  test "ジョブの投入はトランザクションの確定後に行う" do
    assert ApplicationJob.enqueue_after_transaction_commit
    assert DeliverWebhookJob.enqueue_after_transaction_commit
  end

  test "worker の稼働確認と状態確認が実行できる形で置かれている" do
    %w[bin/jobs bin/jobs_alive bin/jobs_status].each do |path|
      full_path = Rails.root.join(path)

      assert File.exist?(full_path), "#{path} が存在しない"
      assert File.executable?(full_path), "#{path} が実行できない"
    end
  end

  test "ジョブ用の表の定義を移行として持つ" do
    migrations = Dir.glob(Rails.root.join("db/queue_migrate/*.rb"))

    assert_equal 1, migrations.size
    assert_includes File.read(migrations.first), "solid_queue_jobs"
    # スキーマは SQL 形式で保持するため、Ruby 形式のスキーマは置かない。
    refute File.exist?(Rails.root.join("db/queue_schema.rb"))
    assert File.exist?(Rails.root.join("db/queue_structure.sql"))
  end

  test "投入の失敗を黙って成功として扱わない" do
    reported = []

    subscriber = Rails.error.subscribe(
      Class.new do
        define_method(:initialize) { |sink| @sink = sink }
        define_method(:report) { |error, **options| @sink << [ error, options ] }
      end.new(reported)
    )

    assert_raises(RuntimeError) do
      JobEnqueue.perform("test") { raise "投入に失敗しました" }
    end

    assert_equal 1, reported.size
    assert_equal "投入に失敗しました", reported.first.first.message
    refute reported.first.last[:handled], "処理済みとして報告している"
  ensure
    Rails.error.unsubscribe(subscriber) if subscriber && Rails.error.respond_to?(:unsubscribe)
  end

  private
    def database_configuration
      YAML.safe_load(
        ERB.new(File.read(Rails.root.join("config/database.yml"))).result,
        aliases: true
      )
    end

    # 環境変数をいったん外し、終わったら必ず戻す。
    def without_environment(*names)
      saved = names.index_with { |name| ENV[name] }
      names.each { |name| ENV.delete(name) }

      yield
    ensure
      saved.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
    end
end
