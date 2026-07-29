require "test_helper"
require_relative "../test_helpers/shell_script_test_helper"

# bin/restore の契約を固定する。
#
# 最も重要なのは、受け付けられない書庫で既存のデータを壊さないことである。
# 壊してから気付いても、戻す手段がない。
class RestoreScriptTest < ActiveSupport::TestCase
  include ShellScriptTestHelper

  test "ファイルから復元できる" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      archive = build_archive(sandbox, storage: { "note.txt" => "書庫の中身" })

      _stdout, stderr, status = sandbox.run("bin/restore", archive, env: { "FORCE" => "1" })

      assert status.success?, stderr
      assert_equal "書庫の中身", sandbox.read("storage", "note.txt")
      assert_includes calls(sandbox), "DROP SCHEMA public CASCADE"
    end
  end

  test "標準入力から復元できる" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      archive = build_archive(sandbox, storage: { "note.txt" => "標準入力から" })

      _stdout, stderr, status = sandbox.run(
        "bin/restore", "--stdin",
        env: { "FORCE" => "1" },
        stdin_data: File.binread(archive)
      )

      assert status.success?, stderr
      assert_equal "標準入力から", sandbox.read("storage", "note.txt")
    end
  end

  test "書庫にない古いファイルを残さない" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      archive = build_archive(sandbox, storage: { "note.txt" => "書庫の中身" })

      File.write(sandbox.path("storage", "stale.txt"), "書庫にない古いファイル")
      FileUtils.mkdir_p(sandbox.path("storage", ".hidden"))
      File.write(sandbox.path("storage", ".hidden", "secret.txt"), "隠しファイル")

      _stdout, stderr, status = sandbox.run("bin/restore", archive, env: { "FORCE" => "1" })

      assert status.success?, stderr
      refute sandbox.exist?("storage", "stale.txt"), "書庫にない古いファイルが残っている"
      refute sandbox.exist?("storage", ".hidden"), "隠しディレクトリが残っている"
      assert_equal "書庫の中身", sandbox.read("storage", "note.txt")
    end
  end

  test "ファイルの保存領域そのものは残す" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      archive = build_archive(sandbox)

      _stdout, _stderr, status = sandbox.run("bin/restore", archive, env: { "FORCE" => "1" })

      assert status.success?
      assert File.directory?(sandbox.path("storage"))
    end
  end

  test "データベースの内容が無い書庫を拒否する" do
    assert_rejected(without: "./database.sql")
  end

  test "データベースの内容が空の書庫を拒否する" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      archive = build_archive(sandbox, database: "")

      assert_no_destruction(sandbox, archive, "データベースの内容が空です")
    end
  end

  test "ファイルの保存領域が無い書庫を拒否する" do
    assert_rejected(without: "./storage")
  end

  test "取得時の情報が無い書庫を拒否する" do
    assert_rejected(without: "./metadata.txt")
  end

  test "書庫として読めないものを拒否する" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      archive = sandbox.path("broken.tar.gz")
      File.binwrite(archive, "これは書庫ではない")

      assert_no_destruction(sandbox, archive, "書庫として読み取れません")
    end
  end

  test "展開先の外を指す書庫を拒否する" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      archive = build_traversal_archive(sandbox)

      assert_no_destruction(sandbox, archive, "展開先の外を指す経路")
    end
  end

  test "絶対パスを含む書庫を拒否する" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      archive = build_absolute_archive(sandbox)

      assert_no_destruction(sandbox, archive, "絶対パスを含んでいます")
    end
  end

  test "確認に応じなければ何も変えない" do
    with_shell_sandbox do |sandbox|
      prepare(sandbox)
      archive = build_archive(sandbox)
      File.write(sandbox.path("storage", "stale.txt"), "残るはず")

      _stdout, _stderr, status = sandbox.run("bin/restore", archive, stdin_data: "no\n")

      refute status.success?
      refute_includes calls(sandbox), "DROP SCHEMA"
      assert sandbox.exist?("storage", "stale.txt")
    end
  end

  private
    def prepare(sandbox)
      sandbox.install_command("psql", ShellScriptTestHelper::PSQL)
      FileUtils.mkdir_p(sandbox.path("storage"))
    end

    # 正しい形の書庫を組み立てる。
    def build_archive(sandbox, storage: {}, database: "-- 取得したデータベースの内容\n", omit: nil)
      source = File.join(sandbox.root, "archive-source-#{SecureRandom.hex(4)}")
      FileUtils.mkdir_p(File.join(source, "storage"))

      File.write(File.join(source, "database.sql"), database) unless omit == "./database.sql"
      File.write(File.join(source, "metadata.txt"), "created_at=20260101T000000Z\n") unless omit == "./metadata.txt"
      FileUtils.rm_rf(File.join(source, "storage")) if omit == "./storage"

      storage.each do |name, body|
        File.write(File.join(source, "storage", name), body)
      end

      archive = File.join(sandbox.root, "archive-#{SecureRandom.hex(4)}.tar.gz")
      system("tar", "--create", "--gzip", "--file=#{archive}", "--directory=#{source}", ".", exception: true)
      archive
    end

    def build_traversal_archive(sandbox)
      source = File.join(sandbox.root, "traversal")
      FileUtils.mkdir_p(source)
      File.write(File.join(sandbox.root, "escaped.txt"), "外へ出るファイル")

      archive = File.join(sandbox.root, "traversal.tar.gz")
      # 展開先の外を指す名前のまま保存する。
      system("tar", "--create", "--gzip", "--absolute-names",
             "--file=#{archive}", "--directory=#{source}", "../escaped.txt",
             exception: true)
      archive
    end

    def build_absolute_archive(sandbox)
      source = File.join(sandbox.root, "absolute")
      FileUtils.mkdir_p(source)
      File.write(File.join(source, "absolute.txt"), "絶対パスのファイル")

      archive = File.join(sandbox.root, "absolute.tar.gz")
      system("tar", "--create", "--gzip", "--absolute-names",
             "--file=#{archive}", File.join(source, "absolute.txt"),
             exception: true)
      archive
    end

    def assert_rejected(without:)
      with_shell_sandbox do |sandbox|
        prepare(sandbox)
        archive = build_archive(sandbox, omit: without)

        assert_no_destruction(sandbox, archive, "書庫を受け付けられません")
      end
    end

    # 拒否したとき、データベースにもファイルにも手を付けていないことを確かめる。
    def assert_no_destruction(sandbox, archive, message)
      File.write(sandbox.path("storage", "existing.txt"), "既存のファイル")

      _stdout, stderr, status = sandbox.run("bin/restore", archive, env: { "FORCE" => "1" })

      refute status.success?, "拒否されるはずの書庫で成功している"
      assert_includes stderr, message
      refute_includes calls(sandbox), "DROP SCHEMA", "検査前にデータベースを壊している"
      assert sandbox.exist?("storage", "existing.txt"), "検査前にファイルを消している"
      assert_equal "既存のファイル", sandbox.read("storage", "existing.txt")
    end
end
