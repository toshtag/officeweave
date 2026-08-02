require "browser_test_case"
require "axe-capybara"
require "axe/api/run"

# アクセシビリティの自動検査。
#
# 判定は axe-core へ任せる。WCAG の達成基準を自分で読み替えて書くと、規格の
# 実装を持つことになり、更新に追随できない。
#
# 自動で判定できるのは基準の一部である。読み上げの順序や文言の分かりやすさは、
# ここでは扱わない。通ったことを「使える」の証明にはしない。
#
# 実ブラウザーで実行する。判定は画面の中で計算した結果（色の対比、要素の
# 見え方、名前の解決）を見るため、HTML の解析では代われない。
class AccessibilityAuditTest < BrowserTestCase
  # 判定に用いる基準。達成基準の版を明示する。
  # 既定のまま任せると、規則が増えたときに何を満たしているのか読めない。
  STANDARD = %i[wcag2a wcag2aa wcag21a wcag21aa].freeze

  # 検査する画面。利用者が日常的に開くものを選ぶ。
  # 一覧、入力、詳細を含める。作りが違えば指摘の出方も違う。
  SCREENS = {
    "入口" => "/",
    "お知らせの一覧" => "/announcements",
    "予定の一覧" => "/events",
    "予定の作成" => "/events/new",
    "文書の一覧" => "/documents",
    "申請の一覧" => "/requests",
    "申請の作成" => "/requests/new",
    "予約の一覧" => "/reservations",
    "設備・備品の一覧" => "/resources",
    "部門の一覧" => "/departments",
    "利用者の一覧" => "/users",
    "自分の設定" => "/settings"
  }.freeze

  SCREENS.each do |name, path|
    test "#{name}に指摘が無い" do
      sign_in_as users(:taro)
      visit path

      assert_accessible
    end
  end

  test "ログインの画面に指摘が無い" do
    visit new_session_path

    assert_accessible
  end

  private
    def assert_accessible
      audit = Axe::Core.new(page).call(Axe::API::Run.new.according_to(*STANDARD))
      results = audit.results

      # 判定が働いていることを確かめる。指摘が無いことだけを見ていると、
      # 判定そのものが動いていない状態に気づけない。
      assert_predicate results.passes, :any?, "判定した規則が 1 つも無い"

      assert audit.passed?, audit.failure_message

      # 判定できなかったものも残さない。保留したまま通すと、
      # 通ったことの意味が薄れる。
      assert_empty results.incomplete.map(&:id), "判定できなかった規則がある"
    end
end
