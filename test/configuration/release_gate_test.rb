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
  #
  # 実測の値そのものは持たない。持つと、記録と一覧の 2 か所で同じ数字を
  # 保つことになり、片方だけが古くなる。正本は検証の記録の文書とし、
  # 一覧はそれを指すだけにする。
  REQUIRED_KEYS = %w[version commit result evaluated_on evidence_document].freeze

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

  test "証拠の文書が、その版の記録を指す" do
    evaluations.each do |evaluation|
      assert_equal "docs/releases/#{evaluation.fetch("version")}_verification.md",
                   evaluation.fetch("evidence_document"),
                   "#{evaluation["version"]} の証拠の文書が、その版の記録ではない"
    end
  end

  # 未実施を成功として数えない。
  #
  # 何をどれだけ測ったかは記録の文書が持つ。ここで見るのは、その記録が
  # 「実行できなかった項目は無い」と述べていることだけとする。数値を
  # 一覧へ写して突き合わせると、写した側が必ず古くなる。
  test "passed の版の記録に、実行できなかった項目が残っていない" do
    assert_not finished?("## 実行できなかった項目\n\nbin/verify を実行できなかった。\n")
    assert finished?("## 実行できなかった項目\n\n無し。\n")

    passed.each do |evaluation|
      body = Rails.root.join(evaluation.fetch("evidence_document")).read

      assert finished?(body), "#{evaluation["version"]} の記録に、実行できなかった項目が残っている"
    end
  end

  # 評価が 1 件も無い時期がある。live の記録だけを見ると、その時期は
  # 何も確かめないまま通る。決めた例で規則そのものを確かめ、そのうえで
  # live の記録へ同じ規則を当てる。
  SAMPLE = {
    "version" => "0.0.1", "commit" => "0" * 40, "result" => "passed",
    "evaluated_on" => "2026-08-06", "evidence_document" => "docs/releases/0.0.1_verification.md"
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
    assert_not File.exist?(Rails.root.join(SAMPLE.fetch("evidence_document")))

    passed.each do |evaluation|
      path = Rails.root.join(evaluation.fetch("evidence_document"))

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

    # 記録が「実行できなかった項目は無い」と述べているか。
    def finished?(body)
      body[/## 実行できなかった項目\s*\n+(.+)/, 1].to_s.strip.start_with?("無し")
    end

    def passed = evaluations.select { |evaluation| evaluation["result"] == "passed" }
end
