require "test_helper"

# 機能到達度の、文章の正本と機械が読む正本が食い違わないことを確かめる。
#
# 2 つ持つのは、判定の理由を人が読む必要があるからである。片方だけを直せる
# 状態にしておくと、必ず食い違う。件数、識別子、状態、入口、証拠、条件の
# 判定を、ここで突き合わせる。
#
# 現在値を都合よく complete へ変えられないようにもする。complete と言えるのは、
# 未達も未評価も 1 つも無い場合だけとする。
class CompletionRegistryTest < ActiveSupport::TestCase
  REGISTRY = Rails.root.join("docs/product/capability_registry.yml").freeze
  MATRIX = Rails.root.join("docs/product/capability_matrix.md").freeze
  RESULTS = %w[met unmet not_applicable not_assessed].freeze
  # 段階ごとに取り得る状態。受入条件の「2.1 段階と状態の組合せ」と同じ。
  ALLOWED = { "core" => %w[partial complete], "suite" => %w[planned partial],
              "extended" => %w[deferred], nil => %w[rejected] }.freeze
  GATE_STATES = %w[planned partial complete].freeze

  setup do
    @registry = YAML.safe_load_file(REGISTRY)
    @matrix = MATRIX.read
    @capabilities = @registry.fetch("capabilities")
    @gates = @registry.fetch("cross_cutting_gates")
  end

  test "完成の条件を固定する" do
    completion = @registry.fetch("completion")

    assert_equal 26, completion.fetch("core_capabilities")
    assert_equal 2, completion.fetch("cross_cutting_gates")
    assert_equal "release.production_readiness", completion.fetch("release_gate")
  end

  test "件数が文章の正本と一致する" do
    assert_equal @registry.dig("completion", "core_capabilities"), @capabilities.size
    assert_equal @registry.dig("completion", "cross_cutting_gates"), @gates.size
    assert_equal core_headings.size, @capabilities.size
    assert_equal gate_headings.size, @gates.size
  end

  test "識別子が重ならない" do
    ids = all_entries.map { |entry| entry.fetch("id") }

    assert_equal ids.size, ids.uniq.size, "識別子が重なっています"
  end

  test "名前が文章の正本の見出しと一致する" do
    assert_equal core_headings.sort, @capabilities.map { |entry| entry.fetch("name") }.sort
    assert_equal gate_headings.sort, @gates.map { |entry| entry.fetch("name") }.sort
  end

  # 片方だけを直せると、読む人と検査で違う結論になる。
  test "状態が文章の正本と一致する" do
    all_entries.each do |entry|
      assert_equal state_in_matrix(entry.fetch("name")), entry.fetch("state"),
                   "#{entry["name"]} の状態が食い違っています"
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
    all_entries.each do |entry|
      entry.fetch("criteria").each do |name, judgement|
        judgement.fetch("evidence").each do |path|
          assert File.exist?(Rails.root.join(path)), "#{entry["id"]} の条件 #{name}: #{path} がありません"
        end
      end
    end
  end

  test "条件の判定が 4 つの値のいずれかである" do
    all_entries.each do |entry|
      entry.fetch("criteria").each do |key, judgement|
        assert_includes RESULTS, judgement.fetch("result"), "#{entry["id"]} の #{key}"
        assert_predicate judgement.fetch("reason").to_s, :present?, "#{entry["id"]} の #{key} に理由が無い"
      end
    end
  end

  # complete を都合よく付けられないようにする。
  test "complete には未達も未評価も無い" do
    all_entries.select { |entry| entry.fetch("state") == "complete" }.each do |entry|
      unresolved = entry.fetch("criteria").select { |_, judgement|
 %w[unmet not_assessed].include?(judgement["result"]) }

      assert_empty unresolved.keys, "#{entry["id"]} は complete にできません"
    end
  end

  test "complete でない機能には、未達か未評価が残っている" do
    all_entries.reject { |entry| entry.fetch("state") == "complete" }.each do |entry|
      unresolved = entry.fetch("criteria").count { |_, judgement| %w[unmet not_assessed].include?(judgement["result"]) }

      assert_operator unresolved + entry.fetch("other_findings").size, :>, 0,
                      "#{entry["id"]} は残りが無いのに complete ではありません"
    end
  end

  # Core の未達と、採用済みの Suite 拡張が重なる項目を見分けられるようにする。
  # 重なりを Core の完成条件へ引き込むと、Suite を実装しない約束と両立しない。
  test "Suite と重なる項目は、持ち主を明示する" do
    suite_ids = suite_identifiers

    all_entries.filter_map { |entry| entry["suite_overlap"]&.merge("id" => entry["id"]) }.each do |overlap|
      assert_includes %w[core_blocker suite], overlap.fetch("owner"), "#{overlap["id"]} の持ち主が不明"
      assert_includes suite_ids, overlap.fetch("suite_id"), "#{overlap["id"]} の指す Suite がありません"
      assert_predicate overlap.fetch("note").to_s, :present?
    end
  end

  test "担当するキャンペーンを持つ" do
    all_entries.reject { |entry| entry.fetch("state") == "complete" }.each do |entry|
      assert_predicate entry.fetch("issue").to_s, :present?, "#{entry["id"]} に担当が無い"
    end
  end

  test "版の判定は識別子と必要な証拠を持ち、まだ評価していない" do
    gate = @registry.fetch("release_gates").sole

    assert_equal "release.production_readiness", gate.fetch("id")
    assert_predicate gate.fetch("required_evidence"), :any?
    assert_empty gate.fetch("evaluations"), "版ごとの評価は、記録ができてから足す"
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

  test "Core 26 件がすべて complete である" do
    assert_equal 26, core.size
    assert_equal [ "complete" ], core.map { |capability| capability.fetch("state") }.uniq
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

    def core_headings = headings("## 2. Core", "## 3. 横断の品質")

    def gate_headings = headings("## 3. 横断の品質", "## 4. Suite")

    def headings(from, to)
      @matrix[/#{Regexp.escape(from)}.*?(?=#{Regexp.escape(to)})/m].scan(/^### (.+)$/).flatten
    end

    def suite_identifiers = @matrix.scan(/`(suite\.[a-z_]+)`/).flatten

    def state_in_matrix(name)
      block = @matrix[/^### #{Regexp.escape(name)}$.*?(?=^### |\A\z|^## )/m]

      block[/^状態  (\w+)/, 1]
    end
end
