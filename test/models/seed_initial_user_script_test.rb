require "test_helper"
require_relative "../test_helpers/shell_script_test_helper"

# 初期利用者を作成するスクリプトの契約を固定する。
#
# 確かめたいのは、資格情報を常駐コンテナへ渡さないことと、値を引数へ載せないこと
# である。Docker の動作そのものではないため、docker を同じ名前の実行ファイルへ
# 差し替え、呼び出しの引数で確かめる。
class SeedInitialUserScriptTest < ActiveSupport::TestCase
  include ShellScriptTestHelper

  # 呼び出しをそのまま記録し、終了状態だけを環境変数で決める。
  FAKE_DOCKER = <<~SCRIPT
    #!/bin/bash
    echo "docker $*" >> "${FAKE_LOG}"
    exit "${FAKE_DOCKER_EXIT:-0}"
  SCRIPT

  test "開発用では一時コンテナで db:seed を実行する" do
    with_shell_sandbox do |sandbox|
      sandbox.install_command("docker", FAKE_DOCKER)

      _stdout, _stderr, status = sandbox.run("script/seed_initial_user")

      assert_predicate status, :success?
      assert_includes calls(sandbox), "run --rm --no-deps"
      assert_includes calls(sandbox), "web bin/rails db:seed"
      assert_not_includes calls(sandbox), "compose.production.yaml"
    end
  end

  test "資格情報は変数名だけを渡し、値を引数へ載せない" do
    with_shell_sandbox do |sandbox|
      sandbox.install_command("docker", FAKE_DOCKER)

      sandbox.run("script/seed_initial_user",
                  env: { "INITIAL_USER_PASSWORD" => "r0-t13-do-not-print-this" })

      recorded = calls(sandbox)

      %w[
        INITIAL_USER_NAME INITIAL_USER_EMAIL INITIAL_USER_PASSWORD
        ORGANIZATION_NAME ORGANIZATION_CODE
      ].each do |name|
        assert_includes recorded, "-e #{name}"
      end

      assert_not_includes recorded, "r0-t13-do-not-print-this"
    end
  end

  test "秘密の値を標準出力にも標準エラーにも出さない" do
    with_shell_sandbox do |sandbox|
      sandbox.install_command("docker", FAKE_DOCKER)

      stdout, stderr, _status = sandbox.run(
        "script/seed_initial_user",
        env: { "INITIAL_USER_PASSWORD" => "r0-t13-do-not-print-this" }
      )

      assert_not_includes stdout, "r0-t13-do-not-print-this"
      assert_not_includes stderr, "r0-t13-do-not-print-this"
    end
  end

  test "常駐する web と worker では実行しない" do
    with_shell_sandbox do |sandbox|
      sandbox.install_command("docker", FAKE_DOCKER)

      sandbox.run("script/seed_initial_user")

      recorded = calls(sandbox)

      assert_not_includes recorded, "exec"
      assert_not_includes recorded, "worker"
    end
  end

  test "配布用では compose.production.yaml を使う" do
    with_shell_sandbox do |sandbox|
      sandbox.install_command("docker", FAKE_DOCKER)

      _stdout, _stderr, status = sandbox.run("script/seed_initial_user", "--production")

      assert_predicate status, :success?
      assert_includes calls(sandbox), "compose -f compose.production.yaml run --rm"
    end
  end

  # 設定の位置と project 名は、run より前のグローバルな引数として渡す。
  test "env ファイルと project 名を run より前へ置く" do
    with_shell_sandbox do |sandbox|
      sandbox.install_command("docker", FAKE_DOCKER)

      sandbox.run("script/seed_initial_user",
                  "--env-file", "/tmp/seed.env",
                  "--project-name", "officeweave_seed_test")

      assert_includes calls(sandbox),
                      "compose --env-file /tmp/seed.env --project-name officeweave_seed_test run --rm"
    end
  end

  test "db:seed の失敗をそのまま返す" do
    with_shell_sandbox do |sandbox|
      sandbox.install_command("docker", FAKE_DOCKER)

      _stdout, _stderr, status = sandbox.run("script/seed_initial_user",
                                             env: { "FAKE_DOCKER_EXIT" => "23" })

      assert_equal 23, status.exitstatus
    end
  end

  test "知らないオプションでは docker を呼ばない" do
    with_shell_sandbox do |sandbox|
      sandbox.install_command("docker", FAKE_DOCKER)

      _stdout, stderr, status = sandbox.run("script/seed_initial_user", "--unknown")

      assert_equal 2, status.exitstatus
      assert_includes stderr, "--unknown"
      assert_empty calls(sandbox)
    end
  end

  test "値のないオプションでは docker を呼ばない" do
    with_shell_sandbox do |sandbox|
      sandbox.install_command("docker", FAKE_DOCKER)

      [ "--env-file", "--project-name" ].each do |option|
        _stdout, stderr, status = sandbox.run("script/seed_initial_user", option)

        assert_equal 2, status.exitstatus, "#{option} が受理された"
        assert_includes stderr, option
      end

      assert_empty calls(sandbox)
    end
  end

  test "説明の表示では docker を呼ばない" do
    with_shell_sandbox do |sandbox|
      sandbox.install_command("docker", FAKE_DOCKER)

      stdout, _stderr, status = sandbox.run("script/seed_initial_user", "--help")

      assert_predicate status, :success?
      assert_includes stdout, "INITIAL_USER_PASSWORD"
      assert_empty calls(sandbox)
    end
  end
end
