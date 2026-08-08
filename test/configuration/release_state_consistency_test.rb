require "test_helper"
require "yaml"

# 版の状態を伝える正本どうしが食い違わないことを固定する。
#
# 版の状態は複数の場所から読める。機能到達度、機械が読む一覧、VERSION、
# 変更履歴である。読む場所によって答えが変わると、どれを信じるかを読む側が
# 決めることになり、文書が判断の材料にならない。
#
# README は対象にしない。利用者へ何をどう書くかは、内部の判定の都合で
# 決めるものではない。
#
# 食い違いは、機能を 1 つ仕上げるたびに生まれる。仕上げた側の文書だけを
# 直し、前に書いた現況を残すためである。人が全部を読み直して気付くことに
# 頼らず、機械が突き合わせる。
class ReleaseStateConsistencyTest < ActiveSupport::TestCase
  MATRIX = Rails.root.join("docs/product/capability_matrix.md")
  CRITERIA = Rails.root.join("docs/product/acceptance_criteria.md")
  RELEASE = Rails.root.join("docs/maintainers/release.md")
  REGISTRY = Rails.root.join("docs/product/capability_registry.yml")
  RELEASES_DIR = Rails.root.join("docs/releases")

  # 実体に無いことを断る記述と、それが成り立つ条件。
  #
  # 「無い」と書いた文は、増えたときに誰も直しに来ない。増えた側の作業は
  # 増えた場所で完結するためである。だから機械が持つ。
  NEGATIVE_CLAIMS = [
    { pattern: /版ごとの評価\s*(?:は)?\s*0\s*件/, meaning: "版ごとの評価が 1 件も無い" },
    { pattern: /版ごとの評価\s+0\s+passed/, meaning: "版ごとの評価が 1 件も無い" },
    { pattern: /評価が\s*1\s*件も無い/, meaning: "版ごとの評価が 1 件も無い" },
    { pattern: /passed した版\s*[はも]?\s*0/, meaning: "passed した版が 1 つも無い" },
    { pattern: /本番準備済みと判定した版は(?:無|な)い/, meaning: "passed した版が 1 つも無い" },
    { pattern: /検証の記録が(?:まだ)?無[いく]/, meaning: "検証の記録が 1 件も無い" },
    { pattern: /docs\/releases\/?`?\s*は存在しない/, meaning: "検証の記録が 1 件も無い" }
  ].freeze

  # 受入条件の文書に置いてはならない、時点に依る表現。
  #
  # この文書は「どうなったら満たすか」を定める。いま何件かは別の文書が
  # 持つ。混ぜると、規範を読みに来た人が古い現況を規範として読む。
  TIME_DEPENDENT = [
    /現時点/,
    /\b\d+\.\d+\.\d+\b/,
    /版ごとの評価\s+\d+\s*件/,
    /passed した版\s+\d+\s*件/,
    /評価が\s*\d+\s*件も無い/,
    /判定した版は(?:無|な)い/
  ].freeze

  setup do
    @registry = YAML.load_file(REGISTRY)
    @evaluations = @registry.fetch("release_gates", []).flat_map { |g| g["evaluations"] || [] }
  end

  test "実体に無いことを断る記述を残していない" do
    stale = []

    [ MATRIX, CRITERIA ].each do |path|
      each_line(path) do |line, number|
        NEGATIVE_CLAIMS.each do |claim|
          next unless line.match?(claim[:pattern])
          next if negative_holds?(claim[:meaning])

          stale << "#{path.relative_path_from(Rails.root)}:#{number} 「#{line.strip}」" \
                   "（#{claim[:meaning]}、は成り立たない）"
        end
      end
    end

    assert_empty stale, "実体と合わない記述が残っている:\n#{stale.join("\n")}"
  end

  test "受入条件の文書が時点に依る記述を持たない" do
    found = []

    each_line(CRITERIA) do |line, number|
      TIME_DEPENDENT.each do |pattern|
        next unless line.match?(pattern)

        found << "#{number} 「#{line.strip}」"
      end
    end

    assert_empty found,
                 "受入条件は規範だけを持つ。現況は機能到達度と機械が読む一覧が持つ:\n#{found.join("\n")}"
  end

  test "公開の手順が特定の版番号を固定していない" do
    found = []

    each_line(RELEASE) do |line, number|
      # 宛先の番号を版数と読み違えない。127.0.0.1 は版ではない。
      next unless line.match?(/(?<![\d.])v?\d+\.\d+\.\d+(?![\d.])/)

      found << "#{number} 「#{line.strip}」"
    end

    assert_empty found,
                 "手順は写して実行される。特定の版を書くと、写した人がその版へ戻す:\n#{found.join("\n")}"
  end

  test "版の呼び名が、すべての正本で一致する" do
    version = Rails.root.join("VERSION").read.strip

    assert_match(/\A\d+\.\d+\.\d+\z/, version, "VERSION の形が版数ではない")

    latest_heading = Rails.root.join("CHANGELOG.md").read[/^##\s+(\d+\.\d+\.\d+)/, 1]
    assert_equal version, latest_heading, "変更履歴の最新の見出しが VERSION と違う"

    latest = @evaluations.last
    assert_not_nil latest, "版ごとの評価が無い"

    # 版数が評価より先に進むのは、実測の途中だけである。版数を実測の前に
    # 決めるため、実測を終えて記録を書くまでのあいだ、評価はひとつ前の版に
    # なる。逆は無い。まだ VERSION が指していない版を評価済みにはできない。
    assert Gem::Version.new(latest["version"]) <= Gem::Version.new(version),
           "機械が読む一覧の評価 #{latest["version"]} が VERSION #{version} より先にある"

    @evaluations.each do |evaluation|
      record = Rails.root.join(evaluation.fetch("evidence_document"))
      assert record.exist?,
             "#{evaluation["version"]} を評価しているのに #{record.basename} が無い"
    end
  end

  test "passed と判定した版が、証拠の文書を持つ" do
    @evaluations.select { |e| e["result"] == "passed" }.each do |evaluation|
      document = Rails.root.join(evaluation.fetch("evidence_document"))

      assert document.exist?,
             "#{evaluation["version"]} に証拠の文書が無いまま passed である"
    end
  end

  private
    def each_line(path)
      path.readlines.each_with_index { |line, index| yield line, index + 1 }
    end

    def negative_holds?(meaning)
      case meaning
      when "版ごとの評価が 1 件も無い" then @evaluations.empty?
      when "passed した版が 1 つも無い" then @evaluations.none? { |e| e["result"] == "passed" }
      when "検証の記録が 1 件も無い" then !RELEASES_DIR.exist? || RELEASES_DIR.glob("*.md").empty?
      else raise ArgumentError, "条件が定義されていない: #{meaning}"
      end
    end
end
