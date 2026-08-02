require "test_helper"

# 一覧の絞り込み。
#
# 件数が増えると、ページを送るだけでは目的の記録へ届かない。
# 絞り込みは、指定が無ければ全件を返す。指定を必須にすると、一覧を
# 開いた時点で何も出ない。
class ListFilterTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:main)
  end

  test "利用者を名前で引ける" do
    assert_includes @organization.users.search("花子"), users(:hanako)
    refute_includes @organization.users.search("花子"), users(:taro)
  end

  test "利用者をメールアドレスで引ける" do
    assert_includes @organization.users.search("hanako@"), users(:hanako)
  end

  test "利用者の検索は指定が無ければ全件を返す" do
    [ nil, "", "   " ].each do |query|
      assert_equal @organization.users.count, @organization.users.search(query).count, query.inspect
    end
  end

  test "利用者を部門で絞れる" do
    filtered = @organization.users.in_department(departments(:sales).id)

    assert_includes filtered, users(:taro)
    refute_includes filtered, users(:outsider_free)
  end

  test "部門の絞り込みは下位部門を含めない" do
    # 指定した部門の人数と、一覧の件数が食い違わないようにする。
    users(:hanako).memberships.create!(department: departments(:sales_east))

    refute_includes @organization.users.in_department(departments(:sales).id), users(:hanako)
  end

  test "利用者を状態で絞れる" do
    users(:hanako).deactivate!

    assert_includes @organization.users.with_state("deactivated"), users(:hanako)
    refute_includes @organization.users.with_state("active"), users(:hanako)
    assert_includes @organization.users.with_state(nil), users(:hanako)
  end

  test "検索の記号は文字として扱う" do
    # 部分一致の記号をそのまま渡すと、すべての記録に当たる。
    assert_empty @organization.users.search("%")
  end

  test "通知を未読だけへ絞れる" do
    read = Notification.create!(user: users(:taro), subject: announcements(:company_wide),
                                event: "announcement_published", read_at: Time.current)
    unread = Notification.create!(user: users(:taro), subject: announcements(:sales_only),
                                  event: "announcement_published")

    filtered = users(:taro).notifications.with_read_state("unread")

    assert_includes filtered, unread
    refute_includes filtered, read
    assert_includes users(:taro).notifications.with_read_state(nil), read
  end

  test "申請を種別で絞れる" do
    filtered = @organization.requests.with_request_type(request_types(:leave).id)

    assert_includes filtered, requests(:taro_leave_pending)
    refute_includes filtered, requests(:hanako_expense_pending)
    assert_includes @organization.requests.with_request_type(nil), requests(:hanako_expense_pending)
  end
end
