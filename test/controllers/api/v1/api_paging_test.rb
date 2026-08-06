require "test_helper"

# API のページングとレート制限。
#
# 外部からの接続は、画面の操作と違って待たずに繰り返せる。1 度に返す量と、
# 一定の時間に受ける回数の両方へ上限を置く。
class Api::V1::ApiPagingTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:main)
    @token = users(:taro).api_tokens.create!(organization: @organization, name: "検証", scopes: ApiToken::SCOPES)
  end

  test "既定の件数で 1 ページ分を返す" do
    (Pagination::DEFAULT_PER_PAGE + 5).times { |index| create_announcement(index) }

    get api_v1_announcements_url, headers: authorization

    assert_response :success
    body = response.parsed_body

    assert_equal Pagination::DEFAULT_PER_PAGE, body["announcements"].size
    assert_equal 1, body.dig("meta", "page")
    assert_equal Pagination::DEFAULT_PER_PAGE, body.dig("meta", "per_page")
  end

  test "件数と総数を伝える" do
    3.times { |index| create_announcement(index) }

    get api_v1_announcements_url, headers: authorization

    meta = response.parsed_body["meta"]

    assert_equal Announcement.visible_to(users(:taro)).count, meta["total_count"]
    assert_equal 1, meta["total_pages"]
  end

  test "ページを指定できる" do
    6.times { |index| create_announcement(index) }

    get api_v1_announcements_url(page: 2, per_page: 2), headers: authorization
    body = response.parsed_body

    assert_equal 2, body["announcements"].size
    assert_equal 2, body.dig("meta", "page")
    refute_equal first_page_ids(per_page: 2), body["announcements"].map { |record| record["id"] }
  end

  test "1 ページの件数は上限を超えない" do
    get api_v1_announcements_url(per_page: Pagination::MAXIMUM_PER_PAGE + 100), headers: authorization

    assert_equal Pagination::MAXIMUM_PER_PAGE, response.parsed_body.dig("meta", "per_page")
  end

  test "読めないページの指定は最初のページとして扱う" do
    get api_v1_announcements_url(page: "abc"), headers: authorization

    assert_response :success
    assert_equal 1, response.parsed_body.dig("meta", "page")
  end

  test "予定、部門、利用者の一覧も目安を返す" do
    [ api_v1_events_url, api_v1_departments_url, api_v1_users_url ].each do |url|
      get url, headers: authorization

      assert_response :success, url
      assert_equal 1, response.parsed_body.dig("meta", "page"), url
    end
  end

  private
    def authorization = { "Authorization" => "Bearer #{@token.token}" }

    def create_announcement(index)
      @organization.announcements.create!(author: users(:taro), title: "知らせ #{index}", body: "本文",
                                          published_at: (index + 1).minutes.ago)
    end

    def first_page_ids(per_page:)
      get api_v1_announcements_url(page: 1, per_page: per_page), headers: authorization

      response.parsed_body["announcements"].map { |record| record["id"] }
    end
end
