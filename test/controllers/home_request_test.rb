require "test_helper"

# 入口の画面が並べる申請。
#
# 承認待ちも、進行中の自分の申請も、ためた分だけ増える。上限を置かないと、
# 処理をためている利用者ほどログイン後の最初の画面が重くなる。
# 本文は 1 件あたり最大 10,000 文字あるが、この画面では表示しない。
class HomeRequestTest < ActionDispatch::IntegrationTest
  include QueryCountTestHelper

  setup do
    @approver = users(:taro)
    @applicant = users(:hanako)
    sign_in_as @approver
  end

  # 並べる件数を超える分だけを増やして、読み込む行の数を 2 回数える。
  # 表示に使う行は増えないため、読み込む行も増えないはずである。
  test "入口が読み込む行の数が、承認待ちの件数で増えない" do
    create_awaiting(HomeController::RECENT_REQUEST_COUNT)

    get root_url
    before = count_rows_read { get root_url }

    create_awaiting(30, offset: HomeController::RECENT_REQUEST_COUNT)

    assert_equal before, count_rows_read { get root_url }
  end

  test "入口が読み込む行の数が、進行中の自分の申請の件数で増えない" do
    create_own(HomeController::RECENT_REQUEST_COUNT)

    get root_url
    before = count_rows_read { get root_url }

    create_own(30, offset: HomeController::RECENT_REQUEST_COUNT)

    assert_equal before, count_rows_read { get root_url }
  end

  test "入口の申請の取得が本文を返さない" do
    create_awaiting(1)
    create_own(1)

    requests = capture_queries { get root_url }
               .select { |query| query[:sql].include?('FROM "requests"') }

    assert_not_empty requests
    requests.each do |query|
      assert_no_match(/"requests"\.\*/, query[:sql], "入口の取得が全列を返している")
    end
  end

  # 件数は表示する分ではなく、承認待ちの総数を示す。上限を置いたあとも
  # 意味を変えない。
  test "承認待ちの件数が、並べた件数ではなく総数になる" do
    create_awaiting(HomeController::RECENT_REQUEST_COUNT + 3)
    total = Request.awaiting_decision_by(@approver).count

    get root_url

    assert_operator total, :>, HomeController::RECENT_REQUEST_COUNT
    assert_select "h3", text: I18n.t("home.requests.awaiting", count: total)
  end

  test "承認待ちは上限までしか並ばない" do
    create_awaiting(HomeController::RECENT_REQUEST_COUNT + 3)

    get root_url

    assert_select "#home-awaiting-requests li", count: HomeController::RECENT_REQUEST_COUNT
  end

  test "進行中の自分の申請は上限までしか並ばない" do
    create_own(HomeController::RECENT_REQUEST_COUNT + 3)

    get root_url

    assert_select "#home-open-requests li", count: HomeController::RECENT_REQUEST_COUNT
  end

  test "承認待ちに申請者が並ぶ" do
    create_awaiting(1)

    get root_url

    assert_select "#home-awaiting-requests .meta", text: @applicant.name
  end

  test "進行中の自分の申請に状態が並ぶ" do
    create_own(1)

    get root_url

    assert_select "#home-open-requests .badge--status-draft"
  end

  test "すべての承認待ちへ移動できる" do
    create_awaiting(1)

    get root_url

    assert_select "a[href=?]", requests_path(scope: "awaiting")
  end

  test "すべての自分の申請へ移動できる" do
    create_own(1)

    get root_url

    assert_select "a[href=?]", requests_path(scope: "mine")
  end

  # 承認も申請もしていない利用者で確かめる。固定のデータには、管理者から見て
  # 承認待ちの申請と、管理者自身が出した申請の両方がある。
  test "対応が必要な申請が無い場合は、その旨を示す" do
    sign_in_as users(:outsider_free)

    get root_url

    assert_select "p", text: I18n.t("home.requests.empty")
  end

  private
    def create_awaiting(count, offset: 0)
      insert_requests(count, offset: offset, applicant: @applicant,
                      title: "承認待ち", status: "pending", submitted: true)
    end

    def create_own(count, offset: 0)
      insert_requests(count, offset: offset, applicant: @approver,
                      title: "自分の申請", status: "draft", submitted: false)
    end

    # 模型を通さずに書き込む。ここで確かめたいのは入口の読み込みであり、
    # 作成の経路ではない。件数を増やす手順の速さが試験の実行時間に直に効く。
    def insert_requests(count, offset:, applicant:, title:, status:, submitted:)
      now = Time.current

      Request.insert_all!(
        count.times.map do |index|
          { organization_id: applicant.organization_id, applicant_id: applicant.id,
            request_type_id: request_types(:expense).id,
            title: "#{title} #{offset + index}", body: "本文" * 100,
            status: status, submitted_at: submitted ? now : nil,
            # 模型を通さないため、決裁の状態の値もここで入れる。
            decision_state_nonce: SecureRandom.hex(16),
            created_at: now, updated_at: now }
        end
      )
    end
end
