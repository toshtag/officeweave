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
            cat > "${FAKE_RECEIVED:-/dev/null}"
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

  # --- 保持 ---

  test "保持の上限を超えた古い書庫を消す" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      place_archives(sandbox, "20260101T000000Z", "20260102T000000Z", "20260103T000000Z")

      stdout, stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: environment(sandbox, running: "db web").merge("BACKUP_KEEP" => "2")
      )

      assert status.success?, stderr
      remaining = archive_names(sandbox)

      # 取得した書庫を含めて 2 件へ収まる。消えるのは名前順で古い側から。
      assert_equal 2, remaining.size
      assert_includes remaining, File.basename(stdout.strip)
      assert_includes remaining, "officeweave-20260103T000000Z.tar.gz"
      refute_includes remaining, "officeweave-20260101T000000Z.tar.gz"
      refute_includes remaining, "officeweave-20260102T000000Z.tar.gz"
    end
  end

  test "保持の上限を指定しなければ古い書庫を消さない" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      place_archives(sandbox, "20260101T000000Z", "20260102T000000Z")

      _stdout, stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: environment(sandbox, running: "db web")
      )

      assert status.success?, stderr
      assert_equal 3, archive_names(sandbox).size
    end
  end

  test "自分が付けた名前に一致しないファイルは消さない" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      place_archives(sandbox, "20260101T000000Z")
      others = %w[
        officeweave.tar.gz
        officeweave-20260101T000000Z.tar.gz.partial
        officeweave-手で作った控え.tar.gz
        organization-notes.txt
      ]
      others.each { |name| File.write(sandbox.path("out", name), "取得したものではない") }

      _stdout, stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: environment(sandbox, running: "db web").merge("BACKUP_KEEP" => "1")
      )

      assert status.success?, stderr
      others.each do |name|
        assert File.exist?(sandbox.path("out", name)), "#{name} を消している"
      end
    end
  end

  test "取得に失敗した場合は古い書庫を消さない" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      place_archives(sandbox, "20260101T000000Z", "20260102T000000Z")

      _stdout, _stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: environment(sandbox, running: "db web")
                .merge("BACKUP_KEEP" => "1", "FAKE_BACKUP_EXIT" => "1")
      )

      refute status.success?
      assert_equal 2, archive_names(sandbox).size
    end
  end

  test "保持の上限が整数でなければ、web を止めずに失敗する" do
    [ "0", "-1", "いくつか", "2.5", "" ].each do |value|
      with_shell_sandbox do |sandbox|
        prepare(sandbox)
        place_archives(sandbox, "20260101T000000Z")

        _stdout, stderr, status = sandbox.run(
          "script/production_backup", sandbox.path("out"),
          env: environment(sandbox, running: "db web").merge("BACKUP_KEEP" => value)
        )

        if value.empty?
          # 空文字は未指定として扱う。整理しないまま取得だけを行う。
          assert status.success?, stderr
          assert_equal 2, archive_names(sandbox).size
        else
          refute status.success?, "#{value.inspect} を受け付けている"
          assert_includes stderr, "BACKUP_KEEP"
          refute_includes calls(sandbox), "stop web"
          assert_equal 1, archive_names(sandbox).size
        end
      end
    end
  end

  test "消した書庫は標準エラーへ出し、標準出力へは書庫の経路だけを出す" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      place_archives(sandbox, "20260101T000000Z")

      stdout, stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: environment(sandbox, running: "db web").merge("BACKUP_KEEP" => "1")
      )

      assert status.success?, stderr
      assert_includes stderr, "officeweave-20260101T000000Z.tar.gz"
      assert_equal [ stdout.strip ], stdout.lines.map(&:strip)
      assert_equal File.basename(stdout.strip), archive_names(sandbox).sole
    end
  end

  test "書庫を消せなければ、取得した書庫を伝えたうえで失敗として返す" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      # 消せないものを、書庫と同じ名前で置く。中身を持つディレクトリは rm で消えない。
      undeletable = sandbox.path("out", "officeweave-20260101T000000Z.tar.gz")
      FileUtils.mkdir_p(File.join(undeletable, "中身"))

      stdout, stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: environment(sandbox, running: "db web").merge("BACKUP_KEEP" => "1")
      )

      refute status.success?
      assert_includes stderr, "削除できませんでした"
      # 取得は成功している。経路を伝えないと、受け取った側が書庫を見つけられない。
      assert File.exist?(stdout.strip)
      assert File.directory?(undeletable)
    end
  end

  # --- 暗号化 ---

  test "パスフレーズを指定すると、書庫を暗号化して残す" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      stdout, stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: encrypted_environment(sandbox, running: "db web")
      )

      assert status.success?, stderr
      archive = stdout.strip

      assert_match(/officeweave-\d{8}T\d{6}Z\.tar\.gz\.enc\z/, archive)
      assert_equal "Salted__", File.binread(archive, 8)
      refute system("tar", "--list", "--gzip", "--file=#{archive}",
                    out: File::NULL, err: File::NULL),
             "暗号化した書庫がそのまま書庫として読める"
    end
  end

  test "暗号化した書庫は openssl だけで取り出せる" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      stdout, stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: encrypted_environment(sandbox, running: "db web")
      )

      assert status.success?, stderr
      decrypted = decrypt(sandbox, stdout.strip)

      assert_includes entries(decrypted), "./database.sql"
    end
  end

  test "パスフレーズを指定しなければ暗号化しない" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      stdout, stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: environment(sandbox, running: "db web")
      )

      assert status.success?, stderr
      assert_includes entries(stdout.strip), "./database.sql"
    end
  end

  test "パスフレーズのファイルが使えなければ、web を止めずに失敗する" do
    cases = {
      "見つからない" => ->(sandbox) { sandbox.path("out", "無いファイル") },
      "1 行目が空" => lambda do |sandbox|
        sandbox.path("empty-line").tap { |path| File.write(path, "\n合言葉\n") }
      end,
      "中身が無い" => ->(sandbox) { sandbox.path("empty").tap { |path| File.write(path, "") } }
    }

    cases.each do |name, build|
      with_shell_sandbox do |sandbox|
        prepare(sandbox)

        _stdout, stderr, status = sandbox.run(
          "script/production_backup", sandbox.path("out"),
          env: environment(sandbox, running: "db web")
                 .merge("BACKUP_PASSPHRASE_FILE" => build.call(sandbox))
        )

        refute status.success?, "#{name} を受け付けている"
        assert_includes stderr, "パスフレーズ"
        refute_includes calls(sandbox), "stop web"
        assert_empty Dir.glob(sandbox.path("out", "*")), "#{name} で書庫が残っている"
      end
    end
  end

  test "暗号化した書庫も保持の対象になる" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      FileUtils.mkdir_p(sandbox.path("out"))
      old = sandbox.path("out", "officeweave-20260101T000000Z.tar.gz.enc")
      FileUtils.cp(File.join(sandbox.root, "archive.tar.gz"), old)

      _stdout, stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: encrypted_environment(sandbox, running: "db web").merge("BACKUP_KEEP" => "1")
      )

      assert status.success?, stderr
      refute File.exist?(old), "暗号化した書庫が整理の対象から外れている"
      assert_equal 1, Dir.glob(sandbox.path("out", "*")).size
    end
  end

  test "取得した書庫を復号できなければ、書庫を残さず失敗する" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      # 暗号化はできるが復号はできない openssl。
      # 取得の直後の確認が働いていなければ、読めない書庫が成果物として残る。
      sandbox.install_command("openssl", <<~SCRIPT)
        #!/bin/bash
        for argument in "$@"; do
          [ "${argument}" = "-d" ] && exit 1
        done
        printf 'Salted__'
        cat
      SCRIPT

      _stdout, stderr, status = sandbox.run(
        "script/production_backup", sandbox.path("out"),
        env: encrypted_environment(sandbox, running: "db web")
      )

      refute status.success?
      assert_includes stderr, "復号"
      assert_empty Dir.glob(sandbox.path("out", "*")), "読めない書庫が残っている"
      # 取得の失敗であり、運用を止め続ける理由はない。
      assert_includes calls(sandbox), "start web"
    end
  end

  test "暗号化された書庫を、復号して復元へ渡す" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      encrypted = encrypt(sandbox, File.join(sandbox.root, "archive.tar.gz"))

      _stdout, stderr, status = sandbox.run(
        "script/production_restore", encrypted,
        env: encrypted_environment(sandbox, running: "db web worker").merge("FORCE" => "1")
      )

      assert status.success?, stderr
      # 復元側が受け取るのは平文の書庫とする。コンテナへパスフレーズを渡さない。
      assert_includes entries(sandbox.path("received.tar.gz")), "./database.sql"
    end
  end

  test "暗号化された書庫をパスフレーズなしで渡すと、web を止めずに失敗する" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      encrypted = encrypt(sandbox, File.join(sandbox.root, "archive.tar.gz"))

      _stdout, stderr, status = sandbox.run(
        "script/production_restore", encrypted,
        env: environment(sandbox, running: "db web").merge("FORCE" => "1")
      )

      refute status.success?
      assert_includes stderr, "暗号化されています"
      refute_includes calls(sandbox), "stop web"
    end
  end

  test "パスフレーズが違えば、web を止めずに失敗する" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      encrypted = encrypt(sandbox, File.join(sandbox.root, "archive.tar.gz"))
      other = sandbox.path("other-passphrase")
      File.write(other, "違う合言葉\n")

      _stdout, stderr, status = sandbox.run(
        "script/production_restore", encrypted,
        env: environment(sandbox, running: "db web")
               .merge("FORCE" => "1", "BACKUP_PASSPHRASE_FILE" => other)
      )

      refute status.success?
      assert_includes stderr, "パスフレーズ"
      refute_includes calls(sandbox), "stop web"
    end
  end

  test "平文の書庫は、パスフレーズを指定していても平文として扱う" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)

      _stdout, stderr, status = sandbox.run(
        "script/production_restore", File.join(sandbox.root, "archive.tar.gz"),
        env: encrypted_environment(sandbox, running: "db web").merge("FORCE" => "1")
      )

      assert status.success?, stderr
      assert_includes entries(sandbox.path("received.tar.gz")), "./database.sql"
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
        "FAKE_ARCHIVE" => File.join(sandbox.root, "archive.tar.gz"),
        # 復元側のコンテナが標準入力から受け取ったものを、そのまま残す。
        "FAKE_RECEIVED" => sandbox.path("received.tar.gz")
      }
    end

    def encrypted_environment(sandbox, running:)
      passphrase = sandbox.path("passphrase")
      File.write(passphrase, "取り違えない合言葉\n")

      environment(sandbox, running: running).merge("BACKUP_PASSPHRASE_FILE" => passphrase)
    end

    # 暗号化と復号は、製品の外にある openssl だけで行う。
    #
    # 指定を script/lib/archive_cipher.sh から読み取らない。ここへ書くのは
    # 「この形なら openssl だけで取り出せる」という約束であり、
    # 実装から読み取ると、約束が変わっても気付けない。
    CIPHER = %w[-aes-256-cbc -md sha256 -pbkdf2 -iter 600000 -salt].freeze

    def encrypt(sandbox, source)
      passphrase = sandbox.path("passphrase")
      File.write(passphrase, "取り違えない合言葉\n") unless File.exist?(passphrase)

      destination = "#{source}.enc"
      system("openssl", "enc", *CIPHER, "-pass", "file:#{passphrase}",
             "-in", source, "-out", destination, exception: true)

      destination
    end

    def decrypt(sandbox, source)
      destination = sandbox.path("decrypted.tar.gz")
      system("openssl", "enc", "-d", *CIPHER, "-pass", "file:#{sandbox.path('passphrase')}",
             "-in", source, "-out", destination, exception: true)

      destination
    end

    def entries(archive)
      `tar --list --gzip --file=#{Shellwords.escape(archive)}`.split("\n")
    end

    # 既に取得済みの書庫として、取得日時だけが違うものを置く。
    def place_archives(sandbox, *timestamps)
      FileUtils.mkdir_p(sandbox.path("out"))

      timestamps.map do |timestamp|
        sandbox.path("out", "officeweave-#{timestamp}.tar.gz").tap do |path|
          FileUtils.cp(File.join(sandbox.root, "archive.tar.gz"), path)
        end
      end
    end

    def archive_names(sandbox)
      Dir.glob(sandbox.path("out", "officeweave-*.tar.gz")).map { |path| File.basename(path) }
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
