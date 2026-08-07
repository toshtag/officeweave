require "test_helper"

# 退行を止めるテストの網羅。
#
# 共通条件 8 は、その機能が持つ入口、実装、権限の判定、並行した操作に、
# 退行を止めるテストがあることを求める。
#
# 機械が読む一覧は、機能ごとに挙げたテストを持つ。ここで見るのは、その一覧が
# 形だけになっていないこと、つまり挙げたテストがその機能の入口を実際に
# 通っていることである。
class RegressionCoverageTest < ActiveSupport::TestCase
  REGISTRY = YAML.load_file(Rails.root.join("docs/product/capability_registry.yml")).freeze

  # 画面を持たない入口。経路ではなくコマンドや設定で示す。
  NON_ROUTE = %r{\A(bin/|script/|config/|compose)}

  test "Core はすべて、退行を止めるテストを挙げている" do
    without = core.reject { |capability| capability.fetch("tests").any? }

    assert_empty without.map { |c| c["id"] }, "テストを挙げる"
  end

  test "挙げたテストが実在する" do
    core.each do |capability|
      capability.fetch("tests").each do |path|
        assert File.exist?(Rails.root.join(path)), "#{capability["id"]}: #{path} がありません"
      end
    end
  end

  test "画面の入口を持つ機能は、その経路を通るテストを挙げている" do
    # 経路を書いただけで、その経路を開くテストが 1 つも無い状態を落とす。
    missing = core.filter_map do |capability|
      routes = capability.fetch("entries").grep_v(NON_ROUTE)
      next if routes.empty?

      sources = capability.fetch("tests").map { |path| Rails.root.join(path).read }.join
      next if routes.any? { |route| covered?(route, sources) }

      "#{capability["id"]}: #{routes.join(' ')}"
    end

    assert_empty missing
  end

  test "権限の判定を持つ機能は、拒む側のテストも挙げている" do
    # 通る側だけを見ると、誰でも通る状態でも通る。
    administrator_only = core.select do |capability|
      capability.fetch("implementation").any? { |path| path.start_with?("app/controllers") } &&
        capability.fetch("tests").any? { |path| Rails.root.join(path).read.include?("require_administrator") }
    end

    administrator_only.each do |capability|
      sources = capability.fetch("tests").map { |path| Rails.root.join(path).read }.join

      assert_match(/forbidden|:forbidden|権限|できない/, sources, "#{capability["id"]}: 拒む側を確かめる")
    end
  end

  test "見ている機能が 26 件である" do
    assert_equal 26, core.size
  end

  test "経路を通るかの判定が働く" do
    # 検査そのものが働くことを、決めた文で確かめる。
    assert covered?("/announcements", "get announcements_url")
    assert covered?("/requests/:request_id/decision", "post request_decision_url(request)")
    assert_not covered?("/announcements", "get documents_url")
  end

  private
    def core = REGISTRY.fetch("capabilities").select { |c| c["stage"] == "core" }

    # 経路が、テストの本文から呼ばれているか。
    # 経路そのものの文字列か、Rails が作る名前のどちらかで現れる。
    def covered?(route, sources)
      name = route.delete_prefix("/").split("/").first.to_s.tr("-", "_")

      return true if sources.include?(route)
      return false if name.blank?

      sources.match?(/\b#{Regexp.escape(name.singularize)}\w*_(?:url|path)\b/)
    end
end
