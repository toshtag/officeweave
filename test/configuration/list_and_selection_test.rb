require "test_helper"

# 一覧の上限と、選択欄の描画量。
#
# 共通条件 4 は一覧に上限があることを、条件 5 は選択欄が対象の件数に比例して
# 描画量を増やさないことを求める。
#
# どちらも、上限を置く仕組みは 1 つずつある。Pagination と DateWindow、
# そして Candidates である。ここで見るのは、一覧と選択欄がそれらを通って
# いることであり、通らない経路が新しく足されていないことである。
class ListAndSelectionTest < ActiveSupport::TestCase
  CONTROLLERS = Rails.root.glob("app/controllers/**/*.rb").freeze
  VIEWS = Rails.root.glob("app/views/**/*.erb").freeze

  # 上限を置く仕組み。
  LIMITS = /Pagination\.new|DateWindow\.new/

  # 一覧を並べる動作。
  LISTING = :index

  # 一覧を持たない制御部。並べる対象を持たないか、抜粋だけを出す。
  WITHOUT_LIST = {
    "home" => "入口は各機能の抜粋だけを出す。上限は件数の定数が持つ",
    "health" => "稼働の確認だけを返す",
    "data_transfers" => "取り込みと書き出しの画面であり、並べる対象を持たない",
    "settings" => "自分の設定だけを出す",
    "sessions" => "ログインの入口であり、並べる対象を持たない",
    "passwords" => "パスワードの変更だけを扱う",
    "password_resets" => "再設定の要求と実行だけを扱う",
    "oidc_sessions" => "認可サーバーとのやり取りだけを扱う",
    "locales" => "表示する言語の切り替えだけを扱う",
    "document_attachments" => "添付の取得だけを扱う。並べるのは文書の画面が行う",
    "memberships" => "所属の追加と解除だけを扱う。並べるのは部門の画面が行う",
    "request_decisions" => "決裁だけを扱う。並べるのは申請の画面が行う",
    "request_submissions" => "提出と取り下げだけを扱う。並べるのは申請の画面が行う",
    "user_activations" => "有効化と無効化だけを扱う。並べるのは利用者の画面が行う"
  }.freeze

  # 対象の件数に比例して描画し得る選択欄。
  # Candidates を通した呼び出しは、先に取り除いてから見る。
  UNBOUNDED_COLLECTION = /(?:current_organization|@organization)\.(?:users|departments|resources)\b/

  test "一覧を並べる制御部は、上限を置く仕組みを通る" do
    missing = listing_controllers.reject { |path| LIMITS.match?(path.read) }

    assert_empty missing.map { |path| path.relative_path_from(Rails.root).to_s },
                 "Pagination か DateWindow を通す"
  end

  test "一覧を持たない制御部は、理由を持つ" do
    # 一覧が無いことと、上限を置き忘れたことを区別する。
    without = CONTROLLERS.reject { |path| path.to_s.include?("/concerns/") || path.to_s.include?("/api/") }
                         .reject { |path| path.read.match?(/def #{LISTING}\b/) }
                         .map { |path| path.basename(".rb").to_s.delete_suffix("_controller") }
                         .reject { |name| name == "application" }

    assert_empty without - WITHOUT_LIST.keys, "一覧を持たない理由を書く"
  end

  test "選択欄は、上限を置く仕組みを通る" do
    offenders = VIEWS.select { |path| UNBOUNDED_COLLECTION.match?(without_candidates(path.read)) }

    assert_empty offenders.map { |path| path.relative_path_from(Rails.root).to_s },
                 "Candidates を通す"
  end

  test "上限を置く仕組みが、実際に上限を持つ" do
    assert_operator Pagination::MAXIMUM_PER_PAGE, :>, 0
    assert_operator Pagination::DEFAULT_PER_PAGE, :<=, Pagination::MAXIMUM_PER_PAGE
    assert_operator DateWindow::MAXIMUM_DAYS, :>, 0
    assert_operator Candidates::LIMIT, :>, 0
  end

  test "見ている制御部が 1 つ以上ある" do
    assert_operator listing_controllers.size, :>=, 10
    assert_operator VIEWS.size, :>=, 60
  end

  test "上限を通らない一覧を見つけられる" do
    # 検査そのものが働くことを、決めた文で確かめる。
    assert_not LIMITS.match?("def index\n  @users = current_organization.users.ordered\nend")
    assert LIMITS.match?("def index\n  @page = Pagination.new(scope)\nend")
    assert UNBOUNDED_COLLECTION.match?("current_organization.users.ordered.each do |user|")
    assert_not UNBOUNDED_COLLECTION.match?(without_candidates("Candidates.new(current_organization.users.ordered)"))
  end

  private
    # Candidates を通した呼び出しを取り除く。通した分は上限を持つ。
    def without_candidates(source)
      source.gsub(/Candidates\.new\((?:[^()]|\([^()]*\))*\)/m, "")
    end

    def listing_controllers
      @listing_controllers ||= CONTROLLERS.select do |path|
        next false if path.to_s.include?("/api/")

        path.read.match?(/def #{LISTING}\b/)
      end
    end
end
