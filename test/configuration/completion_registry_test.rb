require "test_helper"

# 機能到達度の一覧が、形と規則を保っていることを確かめる。
#
# 一覧はこの製品の到達度の正本である。書けてしまう形が広いほど、判定は
# 都合のよい方へ寄る。complete と言えるのは、未達も未評価も 1 つも無い
# 場合だけとする。
#
# 機能（capability）と横断の品質（cross_cutting_gate）は別の形を持つ。
# 機能は Core に共通の条件で判定し、横断の品質は自分が見る条件で判定する。
# 共通の条件を横断の品質にも持たせると、条件を 1 つ増やすたびに、その品質に
# 関係の無い判定を 2 か所へ書き足すことになる。
class CompletionRegistryTest < ActiveSupport::TestCase
  REGISTRY = Rails.root.join("docs/product/capability_registry.yml").freeze
  RESULTS = %w[met unmet not_applicable not_assessed].freeze
  # 段階ごとに取り得る状態。受入条件の「2.1 段階と状態の組合せ」と同じ。
  ALLOWED = { "core" => %w[partial complete], "suite" => %w[planned partial],
              "extended" => %w[deferred], nil => %w[rejected] }.freeze
  GATE_STATES = %w[planned partial complete].freeze
  # 横断の品質の判定。該当しないという判定は持たない。自分が見ると決めた
  # 条件だけを並べるため、該当しないものはそもそも並ばない。
  GATE_RESULTS = %w[met unmet not_assessed].freeze

  setup do
    @registry = YAML.safe_load_file(REGISTRY)
    @capabilities = @registry.fetch("capabilities")
    @gates = @registry.fetch("cross_cutting_gates")
  end

  test "完成の条件は、版の判定を指す" do
    assert_equal "release.production_readiness", @registry.fetch("completion").fetch("release_gate")
  end

  test "識別子が重ならない" do
    ids = all_entries.map { |entry| entry.fetch("id") }

    assert_equal ids.size, ids.uniq.size, "識別子が重なっています"
  end

  test "名前を持つ" do
    all_entries.each do |entry|
      assert_predicate entry.fetch("name").to_s, :present?, "#{entry["id"]} に名前が無い"
    end
  end

  test "段階と状態の組合せが許可された形である" do
    @capabilities.each do |entry|
      allowed = ALLOWED.fetch(entry["stage"])

      assert_includes allowed, entry.fetch("state"), "#{entry["id"]} の組合せが許可されていません"
    end

    @gates.each do |entry|
      assert_nil entry["stage"], "#{entry["id"]} は段階を持たない"
      assert_includes GATE_STATES, entry.fetch("state")
    end
  end

  test "挙げた入口が実際にある" do
    routes = Rails.root.join("config/routes.rb").read
    paths = Rails.application.routes.routes.map { |route| route.path.spec.to_s }

    all_entries.flat_map { |entry| entry.fetch("entries") }.each do |entry|
      next assert File.exist?(Rails.root.join(entry)), "#{entry} がありません" unless entry.start_with?("/")

      assert paths.any? { |path| path.start_with?(entry) } || routes.include?(entry),
             "#{entry} に対応する経路がありません"
    end
  end

  test "挙げた証拠のファイルが実際にある" do
    all_entries.each do |entry|
      %w[implementation tests docs].each do |kind|
        entry.fetch(kind).each do |path|
          assert File.exist?(Rails.root.join(path)), "#{entry["id"]} の #{kind}: #{path} がありません"
        end
      end
    end
  end

  # 条件ごとの証拠も、実在するものだけを挙げる。挙げただけで確かめられない
  # 経路が残ると、判定の根拠をたどれない。
  test "条件の判定に挙げた証拠が実際にある" do
    @capabilities.each do |entry|
      entry.fetch("criteria").each do |name, judgement|
        judgement.fetch("evidence").each do |path|
          assert File.exist?(Rails.root.join(path)), "#{entry["id"]} の条件 #{name}: #{path} がありません"
        end
      end
    end
  end

  test "条件の判定が 4 つの値のいずれかである" do
    @capabilities.each do |entry|
      entry.fetch("criteria").each do |key, judgement|
        assert_includes RESULTS, judgement.fetch("result"), "#{entry["id"]} の #{key}"
        assert_predicate judgement.fetch("reason").to_s, :present?, "#{entry["id"]} の #{key} に理由が無い"
      end
    end
  end

  # complete を都合よく付けられないようにする。
  test "complete には未達も未評価も無い" do
    all_entries.select { |entry| entry.fetch("state") == "complete" }.each do |entry|
      assert_empty unresolved(entry), "#{entry["id"]} は complete にできません"
    end
  end

  test "complete でない機能には、未達か未評価が残っている" do
    all_entries.reject { |entry| entry.fetch("state") == "complete" }.each do |entry|
      assert_operator unresolved(entry).size + entry.fetch("other_findings").size, :>, 0,
                      "#{entry["id"]} は残りが無いのに complete ではありません"
    end
  end

  # 横断の品質は、Core に共通の条件を持たない。自分が見る条件を持つ。
  test "横断の品質が、自分の見る条件を持つ" do
    @gates.each do |gate|
      assert_not gate.key?("criteria"),
                 "#{gate["id"]} が Core の共通条件を持っている"

      checks = gate.fetch("checks")

      assert_predicate checks, :any?, "#{gate["id"]} に見る条件が無い"

      checks.each do |name, check|
        assert_predicate check.fetch("criterion").to_s, :present?, "#{gate["id"]}/#{name} に条件が無い"
        assert_includes GATE_RESULTS, check.fetch("result"), "#{gate["id"]}/#{name} の判定が形式外"
        assert_predicate check.fetch("reason").to_s, :present?, "#{gate["id"]}/#{name} に理由が無い"

        check.fetch("evidence").each do |path|
          assert Rails.root.join(path).exist?, "#{gate["id"]}/#{name} の証拠 #{path} がありません"
        end
      end
    end
  end

  # Core の未達と、採用済みの Suite 拡張が重なる項目を見分けられるようにする。
  # 重なりを Core の完成条件へ引き込むと、Suite を実装しない約束と両立しない。
  test "Suite と重なる項目は、持ち主を明示する" do
    suite_ids = @registry.fetch("suite_capabilities").map { |entry| entry.fetch("id") }

    all_entries.filter_map { |entry| entry["suite_overlap"]&.merge("id" => entry["id"]) }.each do |overlap|
      assert_includes %w[core_blocker suite], overlap.fetch("owner"), "#{overlap["id"]} の持ち主が不明"
      assert_includes suite_ids, overlap.fetch("suite_id"), "#{overlap["id"]} の指す Suite がありません"
      assert_predicate overlap.fetch("note").to_s, :present?
    end
  end

  # Suite、Extended、範囲外は、実装を持たないため機能の一覧とは形が違う。
  # 持つのは識別と、その段階に置いた理由だけである。
  test "実装しない段階の一覧が、形を保っている" do
    @registry.fetch("suite_capabilities").each do |entry|
      assert_match(/\Asuite\./, entry.fetch("id"))
      assert_equal "planned", entry.fetch("state")
      assert_predicate entry.fetch("summary").to_s, :present?, "#{entry["id"]} に内容が無い"
    end

    @registry.fetch("extended_areas").each do |entry|
      assert_equal "deferred", entry.fetch("state")
      assert_predicate entry.fetch("decision_needed").to_s, :present?,
                       "#{entry["name"]} に決める必要のあることが無い"
    end

    @registry.fetch("out_of_scope").each do |entry|
      assert_equal "rejected", entry.fetch("state")
      assert_predicate entry.fetch("reason").to_s, :present?, "#{entry["name"]} に理由が無い"
    end
  end

  test "担当するキャンペーンを持つ" do
    all_entries.reject { |entry| entry.fetch("state") == "complete" }.each do |entry|
      assert_predicate entry.fetch("issue").to_s, :present?, "#{entry["id"]} に担当が無い"
    end
  end

  test "版の判定は識別子と必要な証拠を持つ" do
    gate = @registry.fetch("release_gates").sole

    assert_equal "release.production_readiness", gate.fetch("id")
    assert_predicate gate.fetch("required_evidence"), :any?
  end

  # 評価の形と、書ける条件は release_gate_test.rb が持つ。
  # ここでは、評価を持つ版に検証の記録があることだけを見る。
  test "評価した版には、検証の記録がある" do
    @registry.fetch("release_gates").sole.fetch("evaluations").each do |evaluation|
      path = evaluation.fetch("evidence_document")

      assert File.exist?(Rails.root.join(path)), "#{path} がありません"
    end
  end


  # ここまで来た状態を、後戻りできないようにする。
  #
  # 未評価が 1 件でも戻れば、その機能は完成条件を満たさない。件数で縛ることで、
  # 新しい機能を Core へ足したときにも、評価を伴わなければ落ちる。
  test "Core に未評価が 1 件も無い" do
    unassessed = core.flat_map do |capability|
      capability.fetch("criteria").filter_map { |name, judgement|
 "#{capability["id"]}/#{name}" if judgement["result"] == "not_assessed" }
    end

    assert_empty unassessed
  end

  test "Core に未達が 1 件も無い" do
    unmet = core.flat_map do |capability|
      capability.fetch("criteria").filter_map { |name, judgement|
 "#{capability["id"]}/#{name}" if judgement["result"] == "unmet" }
    end

    assert_empty unmet
  end

  test "Core の機能がすべて complete である" do
    assert_predicate core, :any?, "Core の機能が 1 件も無い"

    incomplete = core.reject { |capability| capability.fetch("state") == "complete" }

    assert_empty incomplete.map { |capability| capability.fetch("id") }
  end

  test "横断の品質がすべて complete である" do
    assert_predicate @gates, :any?, "横断の品質が 1 件も無い"

    incomplete = @gates.reject { |gate| gate.fetch("state") == "complete" }

    assert_empty incomplete.map { |gate| gate.fetch("id") }
  end

  test "判定には、証拠か非該当の理由がある" do
    # 満たすと書きながら証拠が無い状態を落とす。
    missing = core.flat_map do |capability|
      capability.fetch("criteria").filter_map do |name, judgement|
        next if judgement.fetch("reason").to_s.strip.present? &&
                (judgement["result"] != "met" || judgement.fetch("evidence").any?)

        "#{capability["id"]}/#{name}"
      end
    end

    assert_empty missing
  end

  private
    def core = @capabilities.select { |capability| capability["stage"] == "core" }

    def all_entries = @capabilities + @gates

    # 残っている未達と未評価。機能は共通の条件、横断の品質は自分の条件で見る。
    def unresolved(entry)
      judgements = entry["criteria"]&.values || entry.fetch("checks").values

      judgements.select { |judgement| %w[unmet not_assessed].include?(judgement["result"]) }
    end
end
