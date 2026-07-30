require "test_helper"
require "shellwords"
require_relative "../test_helpers/shell_script_test_helper"

# bin/backup の契約を固定する。
#
# 標準出力へ流す経路は、ホスト側が書庫をそのまま受け取ることを前提にしている。
# 進捗が混ざると、受け取った書庫が展開できなくなる。
class BackupScriptTest < ActiveSupport::TestCase
  include ShellScriptTestHelper

  test "ファイル出力で書庫を作る" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      _stdout, stderr, status = sandbox.run("bin/backup", "out")

      assert status.success?, stderr
      archives = Dir.glob(sandbox.path("out", "*.tar.gz"))
      assert_equal 1, archives.size
      assert_includes entries(archives.first), "./database.sql"
    end
  end

  test "標準出力へ流すと、書庫だけが標準出力へ出る" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      stdout, _stderr, status = sandbox.run("bin/backup", "--stdout", binary: true)

      assert status.success?
      # gzip の先頭 2 バイト。進捗が混ざっていれば一致しない。
      assert_equal "\x1F\x8B".b, stdout[0, 2]

      archive = sandbox.path("received.tar.gz")
      File.binwrite(archive, stdout)
      assert_includes entries(archive), "./database.sql"
    end
  end

  test "標準出力へ流すとき、進捗は標準エラーへ出る" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      _stdout, stderr, status = sandbox.run("bin/backup", "--stdout")

      assert status.success?
      assert_includes stderr, "データベースを書き出しています"
    end
  end

  test "書庫に必須の 4 つが含まれる" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      File.write(sandbox.path("storage", "note.txt"), "添付")

      _stdout, _stderr, status = sandbox.run("bin/backup", "out")
      assert status.success?

      names = entries(Dir.glob(sandbox.path("out", "*.tar.gz")).first)
      assert_includes names, "./database.sql"
      # 未処理のジョブも取得する。含めないと、復元で送信待ちが失われる。
      assert_includes names, "./queue_database.sql"
      assert_includes names, "./metadata.txt"
      assert_includes names, "./storage/note.txt"
    end
  end

  test "取得時の情報に版数が入る" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      _stdout, _stderr, status = sandbox.run("bin/backup", "out")
      assert status.success?

      metadata = extract_metadata(Dir.glob(sandbox.path("out", "*.tar.gz")).first)

      assert_match(/created_at=\d{8}T\d{6}Z/, metadata)
      assert_includes metadata, "application_version=9.9.9"
      assert_includes metadata, "schema_version=20260101000000"
      assert_includes metadata, "database_name="
      # 形式 2 から未処理のジョブを含む。
      assert_includes metadata, "format_version=2"
      assert_includes metadata, "queue_database_name="
    end
  end

  test "取得時の情報に秘密情報を書かない" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      _stdout, _stderr, status = sandbox.run("bin/backup", "out", env: { "DATABASE_PASSWORD" => "秘密の値" })
      assert status.success?

      refute_includes extract_metadata(Dir.glob(sandbox.path("out", "*.tar.gz")).first), "秘密の値"
    end
  end

  test "データベースの書き出しに失敗したら 0 以外で終わる" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox, pg_dump: ShellScriptTestHelper::PG_DUMP_FAILURE)

      _stdout, _stderr, status = sandbox.run("bin/backup", "out")

      refute status.success?
      assert_empty Dir.glob(sandbox.path("out", "*.tar.gz")), "失敗した書庫が残っている"
    end
  end

  test "同じ名前の書庫を無条件に上書きしない" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      stdout, _stderr, status = sandbox.run("bin/backup", "out")
      assert status.success?
      # 出力される経路は、実行時の現在地からの相対になる。
      first = sandbox.path(stdout.strip)

      File.write(first, "既にある書庫")

      # 時刻を固定し、同じ秒に取得した状況を作る。
      sandbox.install_command("date", <<~SCRIPT)
        #!/bin/bash
        echo "#{File.basename(first).sub('officeweave-', '').sub('.tar.gz', '')}"
      SCRIPT

      stdout, _stderr, status = sandbox.run("bin/backup", "out")
      assert status.success?
      second = sandbox.path(stdout.strip)

      refute_equal first, second
      assert_equal "既にある書庫", File.read(first)
    end
  end

  test "知らない指定を拒否する" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      _stdout, stderr, status = sandbox.run("bin/backup", "--unknown")

      refute status.success?
      assert_includes stderr, "知らない指定です"
    end
  end

  private
    def prepare(sandbox, pg_dump: ShellScriptTestHelper::PG_DUMP_SUCCESS)
      sandbox.install_command("pg_dump", pg_dump)
      sandbox.install_command("psql", ShellScriptTestHelper::PSQL)
      FileUtils.mkdir_p(sandbox.path("storage"))
      File.write(sandbox.path("VERSION"), "9.9.9\n")
    end

    def entries(archive)
      `tar --list --gzip --file=#{Shellwords.escape(archive)}`.split("\n")
    end

    def extract_metadata(archive)
      `tar --extract --gzip --to-stdout --file=#{Shellwords.escape(archive)} ./metadata.txt`
    end
end
