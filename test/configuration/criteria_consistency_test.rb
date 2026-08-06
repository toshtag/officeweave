require "test_helper"

# 条件ごとの判定が、2 つの正本で食い違わないこと。
#
# 文章の正本は「条件 2 は満たす」と書き、機械が読む一覧は `unmet` を持つ、
# という状態が実際に起きた。件数と状態だけを突き合わせる検査では通ってしまう。
#
# 文章の側は、満たしたことを「条件 N は満たす」、未達を「- N: …」の形で書く。
# その 2 つの書き方だけを読み取り、一覧の判定と突き合わせる。書き方を増やす
# 場合は、ここも直す。
class CriteriaConsistencyTest < ActiveSupport::TestCase
  REGISTRY = YAML.load_file(Rails.root.join("docs/product/capability_registry.yml")).freeze
  MATRIX = Rails.root.join("docs/product/capability_matrix.md").read.freeze

  # 共通条件の並び。番号は受入条件「5. Core に共通の受入条件」に対応する。
  ORDER = %w[
    authorization audit_assignment notification_occurrence list_limit selection_rendering
    database_invariants retention regression_tests documentation localization keyboard
  ].freeze

  test "条件の並びが受入条件と一致する" do
    # 番号と条件の対応がずれると、以下の突き合わせがすべて別の条件を見る。
    assert_equal ORDER, REGISTRY.fetch("capabilities").first.fetch("criteria").keys
  end

  test "文章が満たすと書いた条件を、一覧が未達にしていない" do
    conflicts = sections.flat_map do |id, body|
      satisfied(body).filter_map do |number|
        name = ORDER[number - 1]
        result = judgement(id, name)

        "#{id} の条件 #{number}（#{name}）: 文章は満たす、一覧は #{result}" if result == "unmet"
      end
    end

    assert_empty conflicts
  end

  test "文章が満たすと書いた条件を、一覧が未評価にしていない" do
    conflicts = sections.flat_map do |id, body|
      satisfied(body).filter_map do |number|
        name = ORDER[number - 1]
        result = judgement(id, name)

        "#{id} の条件 #{number}（#{name}）: 文章は満たす、一覧は #{result}" if result == "not_assessed"
      end
    end

    assert_empty conflicts
  end

  test "文章が未達に挙げた条件を、一覧が満たすとしていない" do
    conflicts = sections.flat_map do |id, body|
      unmet(body).filter_map do |number|
        name = ORDER[number - 1]
        result = judgement(id, name)

        "#{id} の条件 #{number}（#{name}）: 文章は未達、一覧は #{result}" if result == "met"
      end
    end

    assert_empty conflicts
  end

  test "突き合わせた節が 1 つ以上ある" do
    # 見出しの書き方が変われば 1 件も読めなくなり、そのまま通る。
    assert_operator sections.size, :>=, 20
    assert_operator sections.sum { |_, body| satisfied(body).size }, :>=, 20
    assert_operator sections.sum { |_, body| unmet(body).size }, :>=, 1
  end

  private
    # 機能の名前を見出しに持つ節を、識別子へ対応づける。
    def sections
      @sections ||= REGISTRY.fetch("capabilities").filter_map do |capability|
        body = section_for(capability.fetch("name"))
        [ capability.fetch("id"), body ] if body
      end
    end

    def section_for(name)
      MATRIX[/^### #{Regexp.escape(name)}$\n(.*?)(?=^### |\z)/m, 1]
    end

    def judgement(id, name)
      REGISTRY.fetch("capabilities").find { |c| c["id"] == id }.fetch("criteria").fetch(name).fetch("result")
    end

    # 満たしたことを書く形は 2 つある。まとめて書く「条件 1・2・8 は満たす」と、
    # 未達の並びのなかへ置く「- 2 は満たす」である。両方を読む。
    # 片方だけを読むと、もう片方の食い違いが黙って通る。
    def satisfied(body)
      grouped = body.scan(/条件 ([\d・]+) は満たす/).flatten
                    .flat_map { |group| group.split("・").map(&:to_i) }

      grouped + body.scan(/^- (\d+) は満たす/).flatten.map(&:to_i)
    end

    # 「- 4: 一覧に上限が無い」の形を読む。
    def unmet(body)
      body.scan(/^- (\d+): /).flatten.map(&:to_i)
    end
end
