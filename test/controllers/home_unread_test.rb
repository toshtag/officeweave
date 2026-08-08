require "test_helper"

# 入口の画面の未読の判定。
#
# 並べるお知らせは `HomeController::RECENT_ANNOUNCEMENT_COUNT` 件に限っている。
# 未読かどうかの判定に蓄積した全件を読み込むと、お知らせが増えるほど
# 入口が重くなる。
class HomeUnreadTest < ActionDispatch::IntegrationTest
  include QueryCountTestHelper

  # 固定のデータにも公開済みのお知らせがある。数え始める前に読んでおき、
  # この試験で作った分だけを未読にする。
  setup do
    @user = users(:outsider_free)
    sign_in_as @user
    Announcement.visible_to(@user).find_each { |announcement| announcement.mark_as_read_by(@user) }
  end

  # 並べる件数を超える分だけを増やして、読み込む行の数を 2 回数える。
  # 表示に使う行は増えないため、読み込む行も増えないはずである。
  test "入口が読み込む行の数が、お知らせの件数で増えない" do
    publish_announcements(HomeController::RECENT_ANNOUNCEMENT_COUNT)

    get root_url
    before = count_rows_read { get root_url }

    publish_announcements(30)

    after = count_rows_read { get root_url }

    assert_equal before, after
  end

  test "未読の件数が表示される" do
    publish_announcements(3)

    get root_url

    assert_select ".badge--unread", text: I18n.t("announcements.unread_count", count: 3)
  end

  test "読んだお知らせは未読の件数へ含まれない" do
    published = publish_announcements(3)
    published.first.mark_as_read_by(@user)

    get root_url

    assert_select ".badge--unread", text: I18n.t("announcements.unread_count", count: 2)
  end

  test "並べる件数を超える未読も、件数には含まれる" do
    total = HomeController::RECENT_ANNOUNCEMENT_COUNT + 3
    publish_announcements(total)

    get root_url

    assert_select ".badge--unread", text: I18n.t("announcements.unread_count", count: total)
  end

  test "未読が無ければ件数を表示しない" do
    get root_url

    assert_select ".badge--unread", false
  end

  private
    def publish_announcements(count)
      count.times.map do |index|
        organizations(:main).announcements.create!(
          author: users(:taro), title: "連絡 #{index}", body: "本文",
          visibility: "organization", published_at: index.minutes.ago
        )
      end
    end
end
