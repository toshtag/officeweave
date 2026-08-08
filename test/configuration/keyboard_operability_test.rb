require "test_helper"

# キーボードだけで操作できること。
#
# 共通条件 `keyboard` は、主要な操作がキーボードだけで完了することを求める。
#
# この製品は画面へスクリプトを配信しない。操作の手段は、押せる要素
# （リンク、ボタン、入力欄）と form だけで組み立てられている。それらは
# ブラウザーが既定で焦点を受け取るため、키ーボードで届く。
#
# 逆に言えば、押せない要素へ操作を載せた時点でキーボードから外れる。
# ここで見るのは、その形が持ち込まれていないことである。
#
# 主要な流れが実際に終えられることは、実ブラウザーの検査が確かめる
# （test/browser/main_flows_test.rb, test/browser/narrow_screen_test.rb）。
class KeyboardOperabilityTest < ActiveSupport::TestCase
  VIEWS = Rails.root.glob("app/views/**/*.erb").freeze

  # 押せない要素へ操作を載せる形。持ち込まれた時点でキーボードから外れる。
  CLICK_ONLY = {
    "onclick" => /onclick\s*=/,
    "javascript: の経路" => /href\s*=\s*["']javascript:/,
    "押せない要素への role" => /role\s*=\s*["'](?:button|link)["']/
  }.freeze

  # 焦点を外す指定。読み飛ばしの受け皿だけが持ってよい。
  FOCUS_REMOVED = /tabindex\s*=\s*["']-1["']/

  # 焦点を外してよい要素。読み飛ばしたあとの移動先である。
  EXPECTED_FOCUS_REMOVED = [ "app/views/layouts/application.html.erb" ].freeze

  test "押せない要素へ操作を載せていない" do
    CLICK_ONLY.each do |name, pattern|
      offenders = VIEWS.select { |path| pattern.match?(path.read) }

      assert_empty offenders.map { |path| path.relative_path_from(Rails.root).to_s },
                   "#{name} を使うと、キーボードから操作できなくなる"
    end
  end

  test "焦点を外している要素が、想定した場所だけである" do
    offenders = VIEWS.select { |path| FOCUS_REMOVED.match?(path.read) }
                     .map { |path| path.relative_path_from(Rails.root).to_s }

    assert_equal EXPECTED_FOCUS_REMOVED.sort, offenders.sort
  end

  test "読み飛ばしのリンクがある" do
    # 移動先の並びを毎回たどらずに本文へ入れるようにする。
    layout = Rails.root.join("app/views/layouts/application.html.erb").read

    assert_includes layout, "skip-link"
    assert_includes layout, "#main"
  end

  test "画面へスクリプトを配信しない" do
    # 配信した時点で、押せる要素だけという前提が崩れる。
    assert_empty Rails.root.glob("app/assets/javascripts/**/*.js")
    assert_empty VIEWS.select { |path| path.read.match?(/<script[\s>]/) }
                      .map { |path| path.relative_path_from(Rails.root).to_s }
  end

  test "主要な流れをキーボードで確かめる検査がある" do
    # 形だけを見ても、流れが終えられることは分からない。
    assert File.exist?(Rails.root.join("test/browser/main_flows_test.rb"))
    assert File.exist?(Rails.root.join("test/browser/narrow_screen_test.rb"))
    assert_includes Rails.root.join("test/browser/narrow_screen_test.rb").read, "キーボードだけで"
  end

  test "見ている画面が 1 つ以上ある" do
    assert_operator VIEWS.size, :>=, 60
  end

  test "押せない要素への操作を見つけられる" do
    # 検査そのものが働くことを、決めた文で確かめる。
    assert CLICK_ONLY["onclick"].match?(%(<div onclick="submit()">押す</div>))
    assert CLICK_ONLY["押せない要素への role"].match?(%(<div role="button">押す</div>))
    assert_not CLICK_ONLY["onclick"].match?(%(<button type="submit">押す</button>))
  end
end
