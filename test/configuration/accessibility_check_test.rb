require "test_helper"

# アクセシビリティの自動検査の組み方を固定する。
#
# 判定を自分で書くと、規格の更新に追随できない。何を基準に、どの画面を、
# どう判定するのかをここで固定する。
class AccessibilityCheckTest < ActiveSupport::TestCase
  AUDIT = Rails.root.join("test/browser/accessibility_audit_test.rb").freeze

  setup do
    @body = AUDIT.read
  end

  test "判定を既存の実装へ任せる" do
    # WCAG の達成基準を自分で読み替えて書くと、規格の実装を持つことになる。
    assert_match(/Axe::Core/, @body)
    assert_no_match(/contrast_ratio|luminance/i, @body, "判定を自分で計算している")
  end

  # 既定のまま任せると、規則が増えたときに何を満たしているのか読めない。
  test "基準の版を明示する" do
    assert_match(/according_to/, @body)
    assert_match(/wcag21aa/, @body)
  end

  # 一覧、入力、詳細では作りが違い、指摘の出方も違う。
  test "利用者が日常的に開く画面を検査する" do
    %w[/announcements /events /events/new /requests /requests/new /users /settings].each do |path|
      assert_includes @body, %("#{path}")
    end
  end

  test "認証の前の画面も検査する" do
    # ログインできなければ、その先の画面には辿り着けない。
    assert_match(/new_session_path/, @body)
  end

  # 指摘が無いことだけを見ていると、判定が動いていない状態に気づけない。
  test "判定が働いていることを確かめる" do
    assert_match(/assert_predicate results\.passes, :any\?/, @body)
  end

  # 判断を保留したまま通すと、通ったことの意味が薄れる。
  test "判定できなかったものを残さない" do
    assert_match(/assert_empty results\.incomplete/, @body)
  end

  test "実ブラウザーの層へ置く" do
    # 色の対比や要素の見え方は、画面の中で計算した結果でなければ判定できない。
    assert_match(/BrowserTestCase/, @body)
  end
end
