require "test_helper"
require_relative "../test_helpers/shell_script_test_helper"

# 開発データベースを作り直すスクリプトの契約を固定する。
#
# 標準の構成では worker が起動し、ジョブ用のデータベースへ接続し続ける。
# その接続を残したまま作り直すと、業務用だけが消えて途中で止まる。
#
# Docker の動作そのものは確かめない。docker を同じ名前の実行ファイルへ
# 差し替え、呼び出しの順と、失敗したときの戻し方で確かめる。
class ResetDevelopmentScriptTest < ActiveSupport::TestCase
  include ShellScriptTestHelper

  SCRIPT = "script/reset_development".freeze

  # 呼び出しを記録する docker。稼働中の service は FAKE_RUNNING で決める。
  # 作り直しの成否は FAKE_RESET_EXIT で決める。
  FAKE_DOCKER = <<~SCRIPT
    #!/bin/bash
    echo "docker $*" >> "${FAKE_LOG}"

    for argument in "$@"; do
      case "${argument}" in
        ps) is_ps=1 ;;
        run) is_run=1 ;;
      esac
    done

    if [ "${is_ps:-0}" = 1 ]; then
      printf '%s\\n' ${FAKE_RUNNING:-db web worker}
      exit 0
    fi

    if [ "${is_run:-0}" = 1 ]; then
      exit "${FAKE_RESET_EXIT:-0}"
    fi

    exit 0
  SCRIPT

  test "準備コマンドは破壊的な操作を持たない" do
    assert_no_match(/--reset/, Rails.root.join("bin/setup").read)
    assert_no_match(/db:reset/, Rails.root.join("bin/setup").read)
  end

  test "作り直しの専用コマンドがある" do
    assert Rails.root.join(SCRIPT).exist?, "#{SCRIPT} が無い"
    assert Rails.root.join(SCRIPT).executable?, "#{SCRIPT} が実行できない"
  end

  test "配布用の構成を対象にしない" do
    body = Rails.root.join(SCRIPT).read

    assert_no_match(/compose\.production\.yaml/, body)
  end

  # 新しいジョブが投入されない状態にしてから worker を止める。
  # 復元と同じ順にそろえる。
  test "web を止めてから worker を止める" do
    recorded = run_reset

    web = recorded.index("docker compose stop web")
    worker = recorded.index("docker compose stop worker")

    assert_not_nil web, "web を止めていない"
    assert_not_nil worker, "worker を止めていない"
    assert_operator web, :<, worker, "worker を先に止めている"
  end

  # 停止した container へは exec できない。
  test "作り直しは一時コンテナで行う" do
    recorded = run_reset

    assert(recorded.any? { |line| line.include?("run --rm --no-deps") && line.include?("db:reset") },
           "一時コンテナで作り直していない")
    assert_not(recorded.any? { |line| line.start_with?("docker compose exec") && line.include?("db:reset") },
               "稼働中の container で作り直している")
  end

  test "止める前に稼働中の service を読む" do
    recorded = run_reset

    listed = recorded.index { |line| line.include?(" ps ") || line.end_with?(" ps") }
    stopped = recorded.index("docker compose stop web")

    assert_not_nil listed, "稼働中の service を読んでいない"
    assert_operator listed, :<, stopped, "読む前に止めている"
  end

  test "作り直しのあとに元の service を起動し直す" do
    recorded = run_reset

    assert_includes recorded, "docker compose start web"
    assert_includes recorded, "docker compose start worker"
  end

  # 元から止まっていたものを、この操作で起動しない。
  test "止まっていた service は起動し直さない" do
    recorded = run_reset(running: "db web")

    assert_includes recorded, "docker compose start web"
    assert_not_includes recorded, "docker compose start worker"
  end

  test "作り直しに失敗しても元の service を起動し直す" do
    recorded = run_reset(reset_exit: 1, expect_success: false)

    assert_includes recorded, "docker compose start web"
    assert_includes recorded, "docker compose start worker"
  end

  test "作り直しに失敗したら失敗として返す" do
    _stdout, _stderr, status = invoke(reset_exit: 1)

    assert_not_predicate status, :success?
  end

  test "データベースが起動していなければ何も止めない" do
    recorded = run_reset(running: "web worker", expect_success: false)

    assert_not_includes recorded, "docker compose stop web"
    assert_not_includes recorded, "docker compose stop worker"
  end

  test "確認を求め、同意しなければ何も止めない" do
    with_shell_sandbox do |sandbox|
      sandbox.install_command("docker", FAKE_DOCKER)

      _stdout, _stderr, status = sandbox.run(SCRIPT, stdin_data: "no\n")

      assert_not_predicate status, :success?
      assert_not_includes calls(sandbox), "stop web"
    end
  end

  test "README が専用コマンドを案内する" do
    readme = Rails.root.join("README.md").read

    assert_includes readme, SCRIPT
  end

  private
    def invoke(running: nil, reset_exit: nil, &block)
      with_shell_sandbox do |sandbox|
        sandbox.install_command("docker", FAKE_DOCKER)

        environment = { "FORCE" => "1" }
        environment["FAKE_RUNNING"] = running if running
        environment["FAKE_RESET_EXIT"] = reset_exit if reset_exit

        result = sandbox.run(SCRIPT, env: environment)
        block&.call(sandbox)

        return result
      end
    end

    # 記録した docker の呼び出しを、順序を保った行の配列で返す。
    def run_reset(running: nil, reset_exit: nil, expect_success: true)
      recorded = nil

      _stdout, _stderr, status = invoke(running: running, reset_exit: reset_exit) do |sandbox|
        recorded = calls(sandbox).lines.map(&:chomp)
      end

      assert_equal expect_success, status.success?, "終了状態が期待と違う"

      recorded
    end
end
