require "test_helper"

# 依存を追加するときの審査手順の正本を、1 か所に保つ。
#
# 同じ規範が 2 つの文書にあると、項目を足したときに片方だけが変わる。
# レビュー担当者がどちらを参照したかで、要求される記録が変わる。
#
# 実際、設計原則の側にだけ「『将来必要になりそう』という理由だけでは
# 追加しない」があり、片側だけが持つ記述が既に生じていた。
class DependencyReviewDocumentTest < ActiveSupport::TestCase
  SOURCE = "docs/development/architecture.md".freeze
  REFERRING = "docs/development/tech_stack.md".freeze

  # PR へ記録する項目。正本に並んでいることを、内容で確かめる。
  ITEMS = [
    "解決する具体的な問題",
    "標準機能だけでは不足する理由",
    "導入しない場合の実装量",
    "依存する公開 API",
    "交換時に影響する範囲",
    "代替候補",
    "削除可能性",
    "ライセンス",
    "保守状況"
  ].freeze

  test "審査の項目が正本に並ぶ" do
    body = read(SOURCE)

    ITEMS.each do |item|
      assert_includes body, item, "#{SOURCE} に「#{item}」が無い"
    end
  end

  test "審査の項目が正本の外に写されていない" do
    ITEMS.each do |item|
      assert_not read(REFERRING).include?(item),
                 "#{REFERRING} へ「#{item}」が写されている"
    end
  end

  test "正本が差し戻しの規則を持つ" do
    assert_includes read(SOURCE), "記録がない依存追加は、レビューで差し戻す"
  end

  # 実証を求める側の文が落ちると、規則だけが残って理由が読めなくなる。
  test "正本が実証を求める理由を持つ" do
    assert_includes read(SOURCE), "「将来必要になりそう」という理由だけでは追加しない"
  end

  # 写しをやめるだけでは、技術構成だけを読む人が手順へ到達できない。
  test "技術構成から正本へ到達できる" do
    # 探す名前は正本の経路から導く。書き写すと、改名したときに
    # link が壊れているのか名前が古いのかを、この検査から判別できない。
    link = read(REFERRING)[%r{\]\(([^)]*#{Regexp.escape(File.basename(SOURCE))}[^)]*)\)}, 1]

    assert_not_nil link, "#{REFERRING} から #{SOURCE} への link が無い"

    path, anchor = link.split("#")
    target = Rails.root.join(File.dirname(REFERRING), path).cleanpath

    assert_equal Rails.root.join(SOURCE), target, "link の指す先が正本ではない"
    assert_includes headings(SOURCE), anchor, "link の指す節が正本に無い" if anchor
  end

  private
    def read(path)
      Rails.root.join(path).read
    end

    # 見出しから GitHub が作る anchor。日本語はそのまま残り、空白は - になる。
    def headings(path)
      read(path).scan(/^#+\s+(.+)$/).flatten.map do |heading|
        heading.strip.downcase.gsub(/[^\p{Word}\s-]/, "").tr(" ", "-")
      end
    end
end
