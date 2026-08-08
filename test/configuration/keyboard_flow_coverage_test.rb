require "test_helper"

# 主要な操作と、画面を持つ Core の対応。
#
# 受入条件 11 は「主要な操作がキーボードだけで完了する」ことを求める。
# 画面を持つ機能に主要な操作が定義されていなければ、その機能について
# 条件 11 は確かめられていない。
#
# 対応そのものをここで固定する。定義の漏れも、対応する検査の欠けも落とす。
class KeyboardFlowCoverageTest < ActiveSupport::TestCase
  REGISTRY = CapabilityRegistryTestHelper.registry.freeze
  FLOWS = YAML.safe_load_file(Rails.root.join("docs/product/keyboard_flows.yml")).fetch("flows").freeze
  SUITE = Rails.root.join("test/browser/keyboard_flows_test.rb").read.freeze

  # 画面を持たない入口。キーボードで操作する対象が無い。
  NON_SCREEN = %r{\A(/api/|/up\z|/health\z|bin/|script/|config/|compose)}

  test "画面を持つ Core すべてに、主要な操作が定義されている" do
    missing = screen_capabilities.map { |c| c["id"] } - FLOWS.map { |flow| flow.fetch("capability") }

    assert_empty missing, "docs/product/keyboard_flows.yml へ定義する"
  end

  test "定義した操作が、画面を持つ Core を指している" do
    known = screen_capabilities.map { |c| c["id"] }
    unknown = FLOWS.map { |flow| flow.fetch("capability") } - known

    assert_empty unknown
  end

  test "定義した操作それぞれに、実ブラウザーの検査がある" do
    missing = FLOWS.reject { |flow| SUITE.include?(%(test "#{flow.fetch("test")}" do)) }

    assert_empty missing.map { |flow| "#{flow["capability"]}: #{flow["test"]}" },
                 "test/browser/keyboard_flows_test.rb へ書く"
  end

  test "実ブラウザーの検査が、定義に無い操作を持たない" do
    defined_names = FLOWS.map { |flow| flow.fetch("test") }
    written = SUITE.scan(/^  test "([^"]+)" do$/).flatten

    assert_empty written - defined_names
  end

  test "主要な操作は、要素を直接指す呼び出しを使わない" do
    # click_link や fill_in は「押せたか」を見るが「到達できたか」を見ない。
    # 到達できない要素でも通ってしまう。
    forbidden = %w[click_link click_button click_on fill_in choose check select]

    forbidden.each do |call|
      assert_no_match(/^\s+#{call}[\s(]/, SUITE, "#{call} はキーボードの証拠にならない")
    end
  end

  test "主要な操作は、キーボードの手順を持つ" do
    # 画面を開くだけで終わる操作を、完遂の証拠として数えない。
    bodies(SUITE).each do |name, body|
      assert_match(/tab_to|skip_to_main/, body, "#{name} にキーボードの移動が無い")
    end
  end

  test "機械が読む一覧の証拠が、実ブラウザーの検査を指す" do
    screen_capabilities.each do |capability|
      evidence = capability.fetch("criteria").fetch("keyboard").fetch("evidence")

      assert_includes evidence, "test/browser/keyboard_flows_test.rb", capability["id"]
    end
  end

  test "画面を持たない Core は、条件 11 を非該当としている" do
    (core - screen_capabilities).each do |capability|
      assert_equal "not_applicable", capability.fetch("criteria").fetch("keyboard").fetch("result"),
                   capability["id"]
    end
  end

  test "見ている機能と操作が 1 つ以上ある" do
    assert_operator screen_capabilities.size, :>=, 20
    assert_equal screen_capabilities.size, FLOWS.size
  end

  private
    def core = REGISTRY.fetch("capabilities").select { |c| c["stage"] == "core" }

    def screen_capabilities
      @screen_capabilities ||= core.select do |capability|
        capability.fetch("entries").any? { |entry| entry !~ NON_SCREEN }
      end
    end

    # 検査ごとの本文。次の test の直前までを 1 つとして取り出す。
    def bodies(source)
      source.split(/^  test "/).drop(1).to_h do |chunk|
        [ chunk[/\A([^"]+)"/, 1], chunk.split(/^  end$/).first.to_s ]
      end
    end
end
