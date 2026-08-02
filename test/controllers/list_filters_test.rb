require "test_helper"

# 一覧の絞り込みを、画面の側から確かめる。
class ListFiltersTest < ActionDispatch::IntegrationTest
  test "利用者を名前で絞れる" do
    sign_in_as users(:taro)

    get users_url(query: "花子")

    assert_response :success
    assert_select "td", text: users(:hanako).name
    assert_select "td", { text: users(:taro).name, count: 0 }
  end

  test "利用者を部門で絞れる" do
    sign_in_as users(:taro)

    get users_url(department_id: departments(:sales).id)

    assert_select "td", text: users(:taro).name
    assert_select "td", { text: users(:outsider_free).name, count: 0 }
  end

  test "利用者を状態で絞れる" do
    users(:hanako).deactivate!
    sign_in_as users(:taro)

    get users_url(state: "deactivated")

    assert_select "td", text: users(:hanako).name
    assert_select "td", { text: users(:taro).name, count: 0 }
  end

  test "知らない状態の指定は絞り込まない" do
    sign_in_as users(:taro)

    get users_url(state: "unknown")

    assert_select "td", text: users(:taro).name
    assert_select "td", text: users(:hanako).name
  end

  test "絞り込みの入力欄が出る" do
    sign_in_as users(:taro)

    get users_url

    assert_select "input[name=query]"
    assert_select "select[name=department_id]"
    assert_select "select[name=state]"
  end

  test "通知を未読だけへ絞れる" do
    read = Notification.create!(user: users(:taro), subject: announcements(:company_wide),
                                event: "announcement_published", read_at: Time.current)
    Notification.create!(user: users(:taro), subject: announcements(:sales_only),
                         event: "announcement_published")
    sign_in_as users(:taro)

    get notifications_url(read_state: "unread")

    assert_response :success
    assert_select "li", { text: /#{announcements(:company_wide).title}/, count: 0 }
    refute_includes response.body, read.subject.title
  end

  test "申請を種別で絞れる" do
    sign_in_as users(:taro)

    get requests_url(request_type_id: request_types(:leave).id)

    assert_select "td", text: /#{requests(:taro_leave_pending).title}/
    assert_select "td", { text: /#{requests(:hanako_expense_pending).title}/, count: 0 }
  end

  test "絞り込みはページ送りへ引き継がれる" do
    30.times { |index| organizations(:main).users.create!(name: "検索対象 #{index}",
                                                          email_address: "target#{index}@example.com",
                                                          password: "a-long-secret-value") }
    sign_in_as users(:taro)

    get users_url(query: "検索対象")

    assert_select "a[href=?]", users_path(page: 2, query: "検索対象")
  end
end
