require "test_helper"

# 版ごとの評価の契約。
#
# 本番準備済みは機能ではなく版に対して判定する。判定を「そう書いた」だけで
# 成立させないため、書ける形をここで縛る。
#
# 最も大事なのは、Core と横断の品質が揃っていない状態で `passed` を書けない
# ことである。揃っていない版を本番準備済みと呼べてしまえば、この一覧は
# 完成の判断に使えない。
class ReleaseGateTest < ActiveSupport::TestCase
  REGISTRY = YAML.load_file(Rails.root.join("docs/product/capability_registry.yml")).freeze

  RESULTS = %w[passed failed].freeze

  # 評価が必ず持つ項目。
  REQUIRED_KEYS = %w[version commit result evaluated_on evidence].freeze

  def gate = REGISTRY.fetch("release_gates").sole

  def evaluations = gate.fetch("evaluations")

  test "版の判定は 1 つだけ定義する" do
    assert_equal "release.production_readiness", gate.fetch("id")
    assert_predicate gate.fetch("required_evidence"), :any?
  end

  test "評価は決めた項目をすべて持つ" do
    assert_equal REQUIRED_KEYS.sort, SAMPLE.keys.sort

    evaluations.each do |evaluation|
      assert_equal REQUIRED_KEYS.sort, evaluation.keys.sort, "#{evaluation["version"]} の項目が違う"
    end
  end

  test "評価の結果は決めた 2 つのいずれかとする" do
    assert_includes RESULTS, SAMPLE.fetch("result")

    evaluations.each do |evaluation|
      assert_includes RESULTS, evaluation.fetch("result")
    end
  end

  test "評価は、必要な証拠をすべて持つ" do
    required = gate.fetch("required_evidence")

    # 決めた例は証拠を持たない。揃っていないことを見分けられる。
    assert_not_equal required.sort, SAMPLE.fetch("evidence").keys.sort

    evaluations.each do |evaluation|
      assert_equal required.sort, evaluation.fetch("evidence").keys.sort,
                   "#{evaluation["version"]} の証拠が揃っていない"
    end
  end

  test "証拠に、実行できなかった項目を残さない" do
    # 未実施を成功として数えない。空欄と「未実施」は、どちらも証拠ではない。
    assert_not blank_or_unfinished?("")
    assert_not blank_or_unfinished?("   ")
    assert_not blank_or_unfinished?("未実施")
    assert blank_or_unfinished?("bin/verify exit 0")

    evaluations.each do |evaluation|
      evaluation.fetch("evidence").each do |name, value|
        assert blank_or_unfinished?(value), "#{evaluation["version"]} の「#{name}」が証拠になっていない"
      end
    end
  end

  # 評価が 1 件も無い時期がある。live の記録だけを見ると、その時期は
  # 何も確かめないまま通る。決めた例で規則そのものを確かめ、そのうえで
  # live の記録へ同じ規則を当てる。
  SAMPLE = {
    "version" => "0.0.1", "commit" => "0" * 40, "result" => "passed",
    "evaluated_on" => "2026-08-06", "evidence" => {}
  }.freeze

  test "Core が揃っていなければ passed にできない" do
    partial = REGISTRY.merge(
      "capabilities" => core.each_with_index.map { |c, index| index.zero? ? c.merge("state" => "partial") : c }
    )

    assert_not ReleaseReadiness.new(partial).allows_passed?,
               "complete でない Core があるのに、passed を許している"
  end

  test "揃っていれば passed を許す" do
    complete = REGISTRY.merge(
      "capabilities" => core.map { |c| c.merge("state" => "complete") },
      "cross_cutting_gates" => REGISTRY.fetch("cross_cutting_gates").map { |g| g.merge("state" => "complete") }
    )

    assert ReleaseReadiness.new(complete).allows_passed?
  end

  test "横断の品質が揃っていなければ passed にできない" do
    partial = REGISTRY.merge(
      "capabilities" => core.map { |c| c.merge("state" => "complete") },
      "cross_cutting_gates" => REGISTRY.fetch("cross_cutting_gates").map { |g| g.merge("state" => "partial") }
    )

    assert_not ReleaseReadiness.new(partial).allows_passed?
  end

  test "揃っていない状態で passed を書いた記録を落とす" do
    written = REGISTRY.merge(
      "capabilities" => core.each_with_index.map { |c, index| index.zero? ? c.merge("state" => "partial") : c },
      "release_gates" => [ gate.merge("evaluations" => [ SAMPLE ]) ]
    )

    assert_not ReleaseReadiness.new(written).valid?
    assert_includes ReleaseReadiness.new(written).problems.join, "complete でない"
  end

  # 揃っている状態では、書いた記録をそのまま受け付ける。
  test "揃っている状態で passed を書いた記録は落とさない" do
    written = REGISTRY.merge("release_gates" => [ gate.merge("evaluations" => [ SAMPLE ]) ])

    assert_predicate ReleaseReadiness.new(written), :valid?
  end

  test "passed の版には、検証の記録がある" do
    # 決めた例の版には記録が無い。無いことを見分けられる。
    assert_not File.exist?(Rails.root.join("docs/releases/#{SAMPLE.fetch("version")}_verification.md"))

    passed.each do |evaluation|
      path = Rails.root.join("docs/releases/#{evaluation.fetch("version")}_verification.md")

      assert File.exist?(path), "#{evaluation["version"]} の検証の記録がありません"
    end
  end

  test "評価した版が、版数の正本と対応する" do
    # 記録に無い版を評価できてしまうと、どの木を測ったのかが分からない。
    known = Rails.root.join("CHANGELOG.md").read

    assert_not_includes known, SAMPLE.fetch("version")

    evaluations.each do |evaluation|
      assert_includes known, evaluation.fetch("version"), "#{evaluation["version"]} が変更履歴に無い"
    end
  end

  test "同じ版を二度評価しない" do
    versions = evaluations.map { |evaluation| evaluation.fetch("version") }

    assert_equal versions.uniq, versions
  end

  private
    def core = REGISTRY.fetch("capabilities").select { |c| c["stage"] == "core" }

    def incomplete_core = core.reject { |c| c.fetch("state") == "complete" }

    # 証拠として受け付けられる値か。
    def blank_or_unfinished?(value)
      value.to_s.strip.present? && value.to_s.exclude?("未実施")
    end

    def passed = evaluations.select { |evaluation| evaluation["result"] == "passed" }
end
