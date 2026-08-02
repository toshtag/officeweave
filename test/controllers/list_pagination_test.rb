require "test_helper"

# 一覧のページ送りを、画面の側から確かめる。
#
# 蓄積する一覧すべてへ同じ形で置く。片方だけに置くと、件数が増えたときに
# 開けなくなる一覧が残る。
class ListPaginationTest < ActionDispatch::IntegrationTest
  # 1 ページに収まらない件数を作るため、1 ページの件数は小さくして確かめる。
  setup do
    @organization = organizations(:main)
  end

  test "利用者の一覧でページを送れる" do
    30.times { |index| create_user(index) }
    sign_in_as users(:taro)

    get users_url

    assert_response :success
    assert_select "nav[aria-label=?]", I18n.t("pagination.label")
    assert_select "a[href=?]", users_path(page: 2)
  end

  test "2 ページ目を開ける" do
    30.times { |index| create_user(index) }
    sign_in_as users(:taro)

    get users_url(page: 2)

    assert_response :success
    assert_select "a[href=?]", users_path(page: 1)
  end

  test "1 ページに収まる一覧にはページ送りを出さない" do
    sign_in_as users(:taro)

    get users_url

    assert_select %(nav[aria-label="#{I18n.t('pagination.label')}"]), count: 0
  end

  test "文書の一覧でページを送れる" do
    30.times { |index| create_document(index) }
    sign_in_as users(:taro)

    get documents_url

    assert_select "a[href=?]", documents_path(page: 2)
  end

  test "文書の一覧では絞り込みを引き継ぐ" do
    30.times { |index| create_document(index) }
    sign_in_as users(:taro)

    get documents_url(query: "手順")

    assert_select "a[href=?]", documents_path(page: 2, query: "手順")
  end

  test "申請の一覧でページを送れる" do
    30.times { |index| create_request(index) }
    sign_in_as users(:taro)

    get requests_url

    assert_select "a[href=?]", requests_path(page: 2)
  end

  test "通知の一覧でページを送れる" do
    30.times { |index| create_notification(index) }
    sign_in_as users(:taro)

    get notifications_url

    assert_select "a[href=?]", notifications_path(page: 2)
  end

  test "監査記録の一覧でページを送れる" do
    (AuditEventsController::PER_PAGE + 1).times { create_audit_event }
    sign_in_as users(:taro)

    get audit_events_url

    assert_select "a[href=?]", audit_events_path(page: 2)
  end

  test "読めないページ番号は最初のページとして扱う" do
    30.times { |index| create_user(index) }
    sign_in_as users(:taro)

    get users_url(page: "abc")

    assert_response :success
    assert_select "a[href=?]", users_path(page: 2)
  end

  private
    def create_user(index)
      @organization.users.create!(name: "利用者 #{index}", email_address: "user#{index}@example.com",
                                  password: "a-long-secret-value")
    end

    def create_document(index)
      @organization.documents.create!(author: users(:taro), title: "手順書 #{index}", body: "本文")
    end

    def create_request(index)
      @organization.requests.create!(request_type: request_types(:leave), applicant: users(:taro),
                                     title: "申請 #{index}")
    end

    # 通知は「利用者、対象、種類」で一意である。対象を分けて作る。
    def create_notification(index)
      announcement = @organization.announcements.create!(author: users(:taro), title: "知らせ #{index}",
                                                        body: "本文", published_at: Time.current)

      Notification.create!(user: users(:taro), subject: announcement, event: "announcement_published")
    end

    def create_audit_event
      AuditEvent.record(organization: @organization, action: "signed_in", actor: users(:taro))
    end
end
