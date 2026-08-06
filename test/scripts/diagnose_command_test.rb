require "test_helper"
require "English"

# 診断のコマンドとしての契約。
#
# 判定そのものは Diagnostics のテストが固定している。ここで見るのは、
# コマンドとして呼んだときの出力の形、終了状態、そして秘密を表示しないこと
# である。運用者はこの 3 つに依存する。自動実行は終了状態だけを見る。
class DiagnoseCommandTest < ActiveSupport::TestCase
  # 出力の形。運用者が読み、記録として残す。
  MARKS = %w[OK 注意 失敗].freeze

  test "確認の一覧と件数を出す" do
    output = run_diagnose(checks: [ ok_check, warning_check ])

    assert_includes output, "OK    データベースへの接続"
    assert_includes output, "注意  ジョブの実行"
    assert_includes output, "確認 2 件、注意 1 件、失敗 0 件"
  end

  test "詳細がある確認は、その行を添える" do
    output = run_diagnose(checks: [ ok_check ])

    assert_includes output, "      つながっています"
  end

  test "詳細が無い確認では、空の行を出さない" do
    output = run_diagnose(checks: [ ok_check(detail: nil) ])

    assert_not_includes output, "\n      \n"
  end

  test "失敗が無ければ 0 で終わる" do
    _output, status = run_diagnose_with_status(checks: [ ok_check, warning_check ])

    assert_predicate status, :zero?
  end

  test "失敗があれば 0 以外で終わる" do
    # 失敗がある状態で 0 を返すと、自動実行で見落とす。
    _output, status = run_diagnose_with_status(checks: [ ok_check, error_check ])

    assert_not_predicate status, :zero?
  end

  test "注意だけでは 0 以外にしない" do
    # 設定として選んだ結果の注意で止めると、注意そのものが読まれなくなる。
    _output, status = run_diagnose_with_status(checks: [ warning_check ])

    assert_predicate status, :zero?
  end

  test "確認が 1 件も無くても壊れない" do
    output, status = run_diagnose_with_status(checks: [])

    assert_includes output, "確認 0 件、注意 0 件、失敗 0 件"
    assert_predicate status, :zero?
  end

  test "印は決めた 3 つだけを使う" do
    output = run_diagnose(checks: [ ok_check, warning_check, error_check ])

    marks = output.lines.filter_map { |line| line[/\A(\S+) {2}\S/, 1] }.uniq

    assert_equal [], marks - MARKS
  end

  test "秘密情報の値そのものを出さない" do
    # 出力は記録として残り、持ち出されることがある。
    secret = "a-very-secret-value"
    check = { name: "秘密情報の初期値", status: :warning,
              detail: "DATABASE_PASSWORD を変更してください。", notify: false }

    output = with_environment("DATABASE_PASSWORD" => secret) { run_diagnose(checks: [ check ]) }

    assert_not_includes output, secret
    assert_includes output, "DATABASE_PASSWORD"
  end

  test "実際の診断でも、秘密情報の値そのものを出さない" do
    secret = "another-secret-value"

    output = with_environment("DATABASE_PASSWORD" => secret, "SMTP_PASSWORD" => secret,
                              "SECRET_KEY_BASE" => secret) do
      capture_output { Diagnostics.new.run.each { |check| puts "#{check[:name]} #{check[:detail]}" } }
    end

    assert_not_includes output, secret
  end


  # 組み立てと判定を切り離した分、コマンドとして起動したときに
  # それらが実際に呼ばれることを 1 度だけ確かめる。
  test "コマンドとして起動でき、出力と終了状態を返す" do
    output = `bin/diagnose 2>&1`
    status = $CHILD_STATUS

    assert_includes output, "確認 "
    assert_includes output, " 件、注意 "
    # この環境では失敗があり得る。0 か 1 のどちらかであることを見る。
    assert_includes [ 0, 1 ], status.exitstatus
    assert_equal output.include?("失敗  "), status.exitstatus == 1
  end

  private
    def ok_check(detail: "つながっています")
      { name: "データベースへの接続", status: :ok, detail: detail, notify: false }
    end

    def warning_check
      { name: "ジョブの実行", status: :warning, detail: "worker が動いていません。", notify: true }
    end

    def error_check
      { name: "データベースの移行", status: :error, detail: "未適用の移行があります。", notify: true }
    end

    def run_diagnose(checks:) = run_diagnose_with_status(checks: checks).first

    # 出力の組み立てと合否の判定は、コマンドが呼ぶものをそのまま呼ぶ。
    # コマンドを起動すると、確かめられる範囲が「動いた・動かない」までになる。
    def run_diagnose_with_status(checks:)
      output = DiagnosticsOutput.new(checks)

      [ output.lines.join("\n") + "\n", output.failed? ? 1 : 0 ]
    end

    def with_environment(values)
      original = values.transform_values { |_| nil }.merge(values.keys.index_with { |key| ENV[key] })
      values.each { |key, value| ENV[key] = value }
      yield
    ensure
      original.each { |key, value| ENV[key] = value }
    end

    def capture_output
      buffer = StringIO.new
      original = $stdout
      $stdout = buffer
      yield
      buffer.string
    ensure
      $stdout = original
    end
end
