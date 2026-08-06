require "test_helper"

# 配送の規約が、文章だけでなく検査として働くことを確かめる。
#
# 規約を説明だけで持つと、急いでいるときに外れる。外れたことにも気付かない。
# 判定そのものを直に呼び、通す条件と落とす条件を固定する。
class DeliveryContractTest < ActiveSupport::TestCase
  SCRIPT = Rails.root.join("script/check_delivery_contract").freeze
  TEMPLATE = Rails.root.join(".github/pull_request_template.md").freeze
  SELF_REVIEW = Rails.root.join("docs/development/self_review.md").freeze
  WORKFLOWS = Rails.root.glob(".github/workflows/*.yml").map(&:read).join("\n").freeze

  load SCRIPT.to_s

  test "検査のコマンドがあり、実行できる" do
    assert_predicate SCRIPT, :exist?
    assert_predicate SCRIPT, :executable?
  end

  test "変更を出すたびに走る" do
    assert_includes WORKFLOWS, "check_delivery_contract",
                    "配送の規約が継続的インテグレーションで走っていない"
  end

  test "規約を満たす commit は通る" do
    assert_empty contract(messages: [ [ "abc1234 fix: 段の判定を直す", "fix: 段の判定を直す\n\n理由" ] ]).violations
  end

  # 生成した道具の付記は、この製品の履歴に残す情報ではない。
  test "共同作者の付記や宣伝は落とす" do
    [ "Co-authored-by: Claude <noreply@anthropic.com>",
      "🤖 Generated with [Claude Code](https://claude.com/claude-code)" ].each do |footer|
      violations = contract(messages: [ [ "abc1234 fix: 直す", "fix: 直す\n\n#{footer}" ] ]).violations

      assert_equal 1, violations.size, "#{footer} が通ってしまいました"
    end
  end

  test "PR の本文も同じ照合を通る" do
    violations = contract(messages: [], body: "Co-authored-by: Claude <noreply@anthropic.com>").violations

    assert_equal 1, violations.size
    assert_equal "PR 本文", violations.sole.where
  end

  # 語そのものをこのリポジトリへ書くと、それ自体が持ち込んだことになる。
  # 照合する語は外から渡す。
  test "持ち込んではいけない語は、外から渡した指定で落とす" do
    violations = contract(messages: [ [ "abc1234 fix: 直す", "fix: 直す\n\nexample-product を参考にした" ] ],
                          restricted: [ /example-product/i ]).violations

    assert_equal 1, violations.size
  end

  test "照合する語の指定が無ければ、その照合だけを飛ばす" do
    assert_empty contract(messages: [ [ "abc1234 fix: 直す", "fix: 直す\n\nexample-product を参考にした" ] ]).violations
  end

  test "commit の題名が日本語かどうかを見分ける" do
    assert japanese?("fix: 段の判定を直す")
    assert_not japanese?("fix: correct the step check")
  end

  test "PR の型と自己レビューの観点がある" do
    template = TEMPLATE.read

    %w[修正前 設計 検証 自己レビュー 未実施].each do |heading|
      assert_includes template, "## #{heading}", "PR の型に #{heading} が無い"
    end

    review = SELF_REVIEW.read

    assert_includes review, "認証、認可、組織の境界"
    assert_includes review, "回帰テストが、修正を外すと意図した理由で落ちるか"
    assert_includes template, "docs/development/self_review.md"
  end

  private
    def contract(messages:, body: nil, restricted: [])
      DeliveryContract.new(messages: messages, body: body, restricted: restricted)
    end
end
