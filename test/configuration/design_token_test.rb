require "test_helper"

# 設計トークンの一覧と、その参照が食い違わないことを固定する。
#
# トークンは「ここから選ぶ」ことを示す一覧である。選ばれないものが混ざると、
# 次に画面を足す人が、使われている値と使われていない値を見分けられない。
# 逆に定義の無いトークンを参照した指定は、既定値のまま静かに外れる。
#
# どちらも画面を開いても分からない。指定そのものを読む。
class DesignTokenTest < ActiveSupport::TestCase
  STYLESHEETS = Rails.root.glob("app/assets/stylesheets/**/*.css").freeze
  DEFINITION = /^\s*(--[a-z0-9-]+):/
  REFERENCE = /var\((--[a-z0-9-]+)/

  setup do
    @body = STYLESHEETS.map(&:read).join("\n")
  end

  test "定義したトークンは、どこかから参照される" do
    assert_empty tokens_of(DEFINITION) - tokens_of(REFERENCE),
                 "var() で読まれないトークンがある"
  end

  test "参照するトークンは、必ず定義されている" do
    assert_empty tokens_of(REFERENCE) - tokens_of(DEFINITION),
                 "定義の無いトークンを読んでいる"
  end

  private
    def tokens_of(pattern) = @body.scan(pattern).flatten.uniq.sort
end
