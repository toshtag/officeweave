require "test_helper"
require_relative "../test_helpers/shell_script_test_helper"

# 配布環境の取得と復元をホストから行うスクリプトの契約を固定する。
#
# 確かめたいのは web の停止と再開の判断であり、Docker の動作ではない。
# docker を同じ名前の実行ファイルへ差し替え、呼び出しの並びで確かめる。
class ProductionBackupScriptsTest < ActiveSupport::TestCase
  include ShellScriptTestHelper

  # docker compose の呼び出しを受け止める。
  # 何が起きたかは FAKE_LOG へ書き足し、応答は環境変数で決める。
  FAKE_DOCKER = <<~SCRIPT
    #!/bin/bash
    echo "docker $*" >> "${FAKE_LOG}"

    subcommand=""
    for argument in "$@"; do
      case "${argument}" in
        docker|compose|-f|compose.production.yaml) continue ;;
        *) subcommand="${argument}"; break ;;
      esac
    done

    case "${subcommand}" in
      ps)
        for service in ${FAKE_RUNNING_SERVICES:-}; do echo "${service}"; done
        ;;
      stop|start)
        exit 0
        ;;
      run)
        case "$*" in
          *bin/backup*)
            [ "${FAKE_BACKUP_EXIT:-0}" -eq 0 ] || exit "${FAKE_BACKUP_EXIT}"
            cat "${FAKE_ARCHIVE}"
            ;;
          *bin/restore*)
            cat > /dev/null
            exit "${FAKE_RESTORE_EXIT:-0}"
            ;;
        esac
        ;;
      exec)
        exit "${FAKE_EXEC_EXIT:-0}"
        ;;
    esac
  SCRIPT

  # --- 取得 ---

  # --- worker ---

  test "web を止めてから worker を止め、web から順に戻す" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      _stdout, stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: environment(sandbox, running: "db web worker")
      )

      assert status.success?, stderr
      log = calls(sandbox)

      # 先に web を止める。新しいジョブが積まれない状態にしてから worker を止める。
      assert_operator log.index("stop web"), :<, log.index("stop worker")
      assert_operator log.index("stop worker"), :<, log.index("bin/backup --stdout")
      # 戻すのは web から。worker は web の稼働を前提に起動する。
      assert_operator log.index("start web"), :<, log.index("start worker")
    end
  end

  test "元々止まっている worker を勝手に起動しない" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      _stdout, stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: environment(sandbox, running: "db web")
      )

      assert status.success?, stderr
      refute_includes calls(sandbox), "stop worker"
      refute_includes calls(sandbox), "start worker"
    end
  end

  test "復元では web と worker を止め、成功時だけ両方を起動する" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      _stdout, stderr, status = sandbox.run(
        "script/production_restore", File.join(sandbox.root, "archive.tar.gz"),
        env: environment(sandbox, running: "db web worker").merge("FORCE" => "1")
      )

      assert status.success?, stderr
      log = calls(sandbox)

      assert_operator log.index("stop web"), :<, log.index("stop worker")
      assert_operator log.index("start web"), :<, log.index("start worker")
      assert_includes log, "bin/jobs_alive"
    end
  end

  test "復元に失敗したら worker も停止したままにする" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      _stdout, stderr, status = sandbox.run(
        "script/production_restore", File.join(sandbox.root, "archive.tar.gz"),
        env: environment(sandbox, running: "db web worker").merge("FORCE" => "1", "FAKE_RESTORE_EXIT" => "1")
      )

      refute status.success?
      assert_includes stderr, "web と worker は停止したままにしています"
      assert_includes calls(sandbox), "stop worker"
      refute_includes calls(sandbox), "start worker"
    end
  end

  # --- 取得 ---

  test "web が動いていれば、停止してから取得し、元へ戻す" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      stdout, stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: environment(sandbox, running: "db web")
      )

      assert status.success?, stderr
      assert File.exist?(stdout.strip)

      log = calls(sandbox)
      assert_includes log, "stop web"
      assert_includes log, "bin/backup --stdout"
      assert_includes log, "start web"
      assert_operator log.index("stop web"), :<, log.index("bin/backup --stdout")
      assert_operator log.index("bin/backup --stdout"), :<, log.index("start web")
    end
  end

  test "元々止まっている web を勝手に起動しない" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      _stdout, stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: environment(sandbox, running: "db")
      )

      assert status.success?, stderr
      refute_includes calls(sandbox), "start web"
      refute_includes calls(sandbox), "stop web"
    end
  end

  test "データベースが動いていなければ何もしない" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      _stdout, stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: environment(sandbox, running: "")
      )

      refute status.success?
      assert_includes stderr, "データベースが起動していません"
      refute_includes calls(sandbox), "stop web"
    end
  end

  test "取得に失敗したら中途半端な書庫を残さない" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      _stdout, stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: environment(sandbox, running: "db web").merge("FAKE_BACKUP_EXIT" => "1")
      )

      refute status.success?
      assert_includes stderr, "バックアップの取得に失敗しました"
      assert_empty Dir.glob(sandbox.path("out", "*")), "失敗したのに書庫が残っている"
    end
  end

  test "取得に失敗しても、元々動いていた web は再開する" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      _stdout, _stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: environment(sandbox, running: "db web").merge("FAKE_BACKUP_EXIT" => "1")
      )

      refute status.success?
      assert_includes calls(sandbox), "start web"
    end
  end

  test "受け取ったものが書庫でなければ失敗する" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      File.binwrite(File.join(sandbox.root, "archive.tar.gz"), "書庫ではない")

      _stdout, stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: environment(sandbox, running: "db web")
      )

      refute status.success?
      assert_includes stderr, "読み取れません"
      assert_empty Dir.glob(sandbox.path("out", "*"))
    end
  end

  # --- 復元 ---

  test "復元に成功した場合だけ web を起動する" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      _stdout, stderr, status = sandbox.run(
        "script/production_restore", File.join(sandbox.root, "archive.tar.gz"),
        env: environment(sandbox, running: "db web").merge("FORCE" => "1")
      )

      assert status.success?, stderr
      log = calls(sandbox)
      assert_includes log, "stop web"
      assert_includes log, "bin/restore --stdin"
      assert_includes log, "start web"
      assert_includes log, "bin/diagnose"
    end
  end

  test "復元に失敗したら web を停止したままにする" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      _stdout, stderr, status = sandbox.run(
        "script/production_restore", File.join(sandbox.root, "archive.tar.gz"),
        env: environment(sandbox, running: "db web").merge("FORCE" => "1", "FAKE_RESTORE_EXIT" => "1")
      )

      refute status.success?
      assert_includes stderr, "停止したままにしています"
      assert_includes calls(sandbox), "stop web"
      refute_includes calls(sandbox), "start web"
    end
  end

  test "確認に応じなければ web を止めない" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      _stdout, _stderr, status = sandbox.run(
        "script/production_restore", File.join(sandbox.root, "archive.tar.gz"),
        env: environment(sandbox, running: "db web"),
        stdin_data: "no\n"
      )

      refute status.success?
      refute_includes calls(sandbox), "stop web"
    end
  end

  test "書庫として読めないものは、web を止める前に拒否する" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      broken = File.join(sandbox.root, "broken.tar.gz")
      File.binwrite(broken, "書庫ではない")

      _stdout, stderr, status = sandbox.run(
        "script/production_restore", broken,
        env: environment(sandbox, running: "db web").merge("FORCE" => "1")
      )

      refute status.success?
      assert_includes stderr, "書庫として読み取れません"
      refute_includes calls(sandbox), "stop web"
    end
  end

  private
    def prepare(sandbox)
      sandbox.install_command("docker", FAKE_DOCKER)
      build_archive(File.join(sandbox.root, "archive.tar.gz"), sandbox)
    end

    def environment(sandbox, running:)
      {
        "FAKE_RUNNING_SERVICES" => running,
        "FAKE_ARCHIVE" => File.join(sandbox.root, "archive.tar.gz")
      }
    end

    def build_archive(destination, sandbox)
      source = File.join(sandbox.root, "archive-source")
      FileUtils.mkdir_p(File.join(source, "storage"))
      File.write(File.join(source, "database.sql"), "-- 取得したデータベースの内容\n")
      File.write(File.join(source, "metadata.txt"), "created_at=20260101T000000Z\n")

      system("tar", "--create", "--gzip", "--file=#{destination}", "--directory=#{source}", ".",
             exception: true)
    end
end
