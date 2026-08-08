require "test_helper"

# 操作の手引きの網羅。
#
# 画面を持つ機能には、その画面を使う役割が読める手順が要る（共通条件 9）。
# 文書を書いたかどうかは、書いた本人にしか分からない。機械が読む一覧の側から
# 突き合わせ、書き忘れをここで落とす。
#
# 中身の良し悪しは見ない。見られるのは、その機能を扱う節が実在することまでで
# ある。読んで分かるかどうかは、人が読んで判断する。
class UsageDocumentationTest < ActiveSupport::TestCase
  REGISTRY = CapabilityRegistryTestHelper.registry.freeze

  # 手引きの置き場所。
  USAGE = "docs/usage".freeze

  # 画面を持たない入口。手引きの対象にしない。
  NON_SCREEN = %r{\A(/api/|/up\z|/health\z|bin/|script/|config/|compose)}

  test "画面を持つ Core すべてが、手引きを挙げている" do
    missing = screen_capabilities.reject do |capability|
      capability.fetch("docs").any? { |path| path.start_with?(USAGE) }
    end

    assert_empty missing.map { |capability| capability["id"] },
                 "手引きを docs へ挙げていない機能がある"
  end

  test "挙げた手引きが実在する" do
    screen_capabilities.each do |capability|
      capability.fetch("docs").grep(/\A#{USAGE}/).each do |path|
        assert File.exist?(Rails.root.join(path)), "#{capability["id"]}: #{path} がありません"
      end
    end
  end

  test "手引きの索引が、すべての手引きを指す" do
    index = Rails.root.join(USAGE, "index.md").read

    Rails.root.glob("#{USAGE}/*.md").each do |path|
      name = path.basename.to_s
      next if name == "index.md"

      assert_includes index, name, "索引が #{name} を指していない"
    end
  end

  test "手引きから挙げた相対の経路が実在する" do
    Rails.root.glob("#{USAGE}/*.md").each do |path|
      path.read.scan(/\]\((\.\.?\/[^)#]+)/).flatten.each do |link|
        target = path.dirname.join(link).cleanpath

        assert File.exist?(target), "#{path.basename}: #{link} がありません"
      end
    end
  end

  test "画面を持つ機能の判定に、手引きが証拠として挙がっている" do
    screen_capabilities.each do |capability|
      judgement = capability.fetch("criteria").fetch("documentation")
      next unless judgement["result"] == "met"

      assert judgement.fetch("evidence").any? { |path| path.start_with?(USAGE) },
             "#{capability["id"]}: 条件 9 を満たすとしながら、手引きを証拠に挙げていない"
    end
  end

  test "画面を持つ機能を 1 件以上見ている" do
    # 抽出の条件を間違えると、1 件も見ないまま通る。
    assert_operator screen_capabilities.size, :>=, 10
  end

  private
    def screen_capabilities
      @screen_capabilities ||= REGISTRY.fetch("capabilities").select do |capability|
        capability["stage"] == "core" &&
          capability.fetch("entries").any? { |entry| entry !~ NON_SCREEN }
      end
    end
end
