require "test_helper"

# 利用者の一覧が出す問い合わせ。
#
# 主たる所属は行ごとに表示する。所属を利用者ごとに引くと、件数は組織の
# 利用者数に比例して増える。
class UserListTest < ActionDispatch::IntegrationTest
  include QueryCountTestHelper

  setup do
    sign_in_as users(:taro)
  end

  # 利用者の人数だけを変えて、同じ取得を 2 回数える。
  test "利用者の一覧で出る問い合わせが、利用者の人数で増えない" do
    get users_url

    before = count_queries { get users_url }

    add_users(20)

    after = count_queries { get users_url }

    assert_equal before, after
  end

  test "主たる所属が表示される" do
    get users_url

    assert_select "td", text: departments(:sales).name
  end

  test "主たる所属を持たない利用者は、所属なしとして表示される" do
    get users_url

    assert_select "td", text: I18n.t("departments.no_parent")
  end

  private
    # 照合の速さはテストの実行時間に直に効く。固定のデータと同じ最小の負荷を使う。
    def add_users(count)
      digest = BCrypt::Password.create("password-for-tests", cost: BCrypt::Engine::MIN_COST)

      count.times do |index|
        user = organizations(:main).users.create!(
          name: "利用者 #{index}", email_address: "listed#{index}@example.com",
          password_digest: digest
        )
        user.memberships.create!(department: departments(:development), primary: true)
      end
    end
end
