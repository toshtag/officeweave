require "test_helper"

# 配布用のイメージの検査で、非該当と判断した指摘を記録して通す仕組みの契約。
#
# 実際に検査器を走らせて確かめない。取得する脆弱性のデータベースは日ごとに
# 変わり、そのときの指摘の件数は確かめたいことではない。確かめたいのは、
# 記録が当たる条件と、当たらないときに落ちることである。
class ContainerScanExceptionTest < ActiveSupport::TestCase
  EVALUATOR = Rails.root.join("script/evaluate_container_scan").freeze
  EXCEPTIONS = Rails.root.join("config/container_scan_exceptions.yml").freeze

  # 判定の本体だけを読み込む。コマンドとしての実行部は、読み込みでは動かない。
  load EVALUATOR.to_s

  setup do
    @finding = {
      "VulnerabilityID" => "CVE-2026-33210", "PkgName" => "json",
      "InstalledVersion" => "2.18.0", "FixedVersion" => "2.18.0", "Severity" => "CRITICAL"
    }
  end

  test "記録の無い指摘は失敗する" do
    evaluation = evaluate(findings: [ @finding ], accepted: [])

    assert_not_predicate evaluation, :passed?
    assert_equal 1, evaluation.unaccepted.size
    assert_empty evaluation.accepted
  end

  test "根拠と期限を持つ記録があれば通る" do
    evaluation = evaluate(findings: [ @finding ], accepted: [ record ])

    assert_predicate evaluation, :passed?
    assert_empty evaluation.unaccepted
  end

  # 通すことと、見せないことは分ける。
  test "記録して通した指摘は報告に残る" do
    evaluation = evaluate(findings: [ @finding ], accepted: [ record ])

    assert_equal [ "CVE-2026-33210 json 2.18.0 (CRITICAL)" ], evaluation.accepted.map(&:to_s)
  end

  # 指摘は入っている版に対して出る。版が上がれば、同じ意味を持つとは限らない。
  test "版が変われば記録は当たらない" do
    evaluation = evaluate(findings: [ @finding.merge("InstalledVersion" => "2.19.0") ],
                          accepted: [ record ])

    assert_not_predicate evaluation, :passed?
    assert_equal 1, evaluation.unaccepted.size
  end

  test "識別子や package が違えば記録は当たらない" do
    [ { "VulnerabilityID" => "CVE-2026-00000" }, { "PkgName" => "psych" } ].each do |difference|
      evaluation = evaluate(findings: [ @finding.merge(difference) ], accepted: [ record ])

      assert_not_predicate evaluation, :passed?, "#{difference} で通ってしまいました"
    end
  end

  # 判断は、そのときの状況に対して行ったものである。恒久的な除外を作らない。
  test "期限を過ぎた記録は当たらず、期限切れとして示される" do
    evaluation = evaluate(findings: [ @finding ], accepted: [ record(review_by: "2020-01-01") ])

    assert_not_predicate evaluation, :passed?
    assert_equal 1, evaluation.expired.size
    assert_equal 1, evaluation.unaccepted.size
  end

  test "根拠や期限を欠く記録は、記録として扱わない" do
    %w[reason review_by installed_version package id].each do |key|
      evaluation = evaluate(findings: [ @finding ], accepted: [ record.except(key) ])

      assert_not_predicate evaluation, :passed?, "#{key} が無くても通ってしまいました"
      assert_equal 1, evaluation.malformed.size
    end
  end

  # 記録が 1 件も当たらなくても、指摘そのものが無ければ落とさない。
  test "指摘が無ければ通る" do
    assert_predicate evaluate(findings: [], accepted: []), :passed?
  end

  # 修正版の無い指摘で止め続けると、失敗を無視する習慣がつく。
  test "修正版の無い指摘は合否に使わない" do
    evaluation = evaluate(findings: [ @finding.merge("FixedVersion" => "") ], accepted: [])

    assert_predicate evaluation, :passed?
    assert_empty evaluation.unaccepted
  end

  test "記録の置き場所があり、書き方が読める" do
    body = EXCEPTIONS.read

    assert_includes body, "accepted:"
    assert_includes body, "期限"
    assert_includes body, "版"
  end

  # 検査のコマンドが、この判定を通ることを固定する。
  test "検査のコマンドが記録と突き合わせる" do
    body = Rails.root.join("script/scan_container_image").read

    assert_includes body, "config/container_scan_exceptions.yml"
    assert_includes body, "evaluate_container_scan"
    assert_match(/--format json --output "\/report\/\$3-fixable\.json"/, body)
  end

  private
    def record(review_by: (Date.today + 90).to_s)
      { "id" => "CVE-2026-33210", "package" => "json", "installed_version" => "2.18.0",
        "reason" => "同梱された版は読み込まれない", "review_by" => review_by }
    end

    def evaluate(findings:, accepted:)
      ContainerScanEvaluation.new(
        report: { "Results" => [ { "Vulnerabilities" => findings } ] },
        exceptions: { "accepted" => accepted }
      )
    end
end
