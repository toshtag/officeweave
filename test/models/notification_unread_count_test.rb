require "test_helper"

# 未読の通知の件数を数える経路。
#
# 見出し領域へ常に出すため、認証済みのすべての画面で 1 回ずつ実行される。
# 既読の通知は消えないため、絞り込みに合う索引が無いと、走査する量が
# その利用者の通知履歴に比例して増え続ける。
class NotificationUnreadCountTest < ActiveSupport::TestCase
  UNREAD_INDEX = "index_notifications_on_unread_user_id".freeze

  # 索引の有無で確かめる。実行の速さで確かめると、実行環境の速さと、
  # そのときのデータ量で planner の選択が変わり、間欠的に失敗する。
  test "未読の件数のための索引がある" do
    assert_includes indexes.map(&:name), UNREAD_INDEX
  end

  # 索引が持つのは未読の行だけである。既読を含めると、走査する量が
  # 通知履歴に比例したままになる。
  test "索引が未読の行だけを持つ" do
    index = indexes.find { |candidate| candidate.name == UNREAD_INDEX }

    assert_equal [ "user_id" ], index.columns
    # 条件の書き方はデータベースが正規化する。括弧の有無までは押さえない。
    assert_match(/read_at IS NULL/, index.where.to_s)
  end

  # 索引の条件と絞り込みが食い違えば、索引は使われない。同じ条件であることを
  # 絞り込みの側からも押さえる。
  test "未読の絞り込みが索引の条件と同じ" do
    assert_includes Notification.unread.to_sql, %q("notifications"."read_at" IS NULL)
  end

  test "未読の件数が既読を数えない" do
    user = users(:hanako)
    unread = create_notification(user, "未読のお知らせ")
    create_notification(user, "既読のお知らせ").mark_as_read

    assert_equal 1, user.notifications.unread.count
    assert_equal [ unread.id ], user.notifications.unread.pluck(:id)
  end

  private
    def indexes
      ActiveRecord::Base.connection.indexes(:notifications)
    end

    def create_notification(user, title)
      subject = organizations(:main).announcements.create!(
        author: users(:taro), title: title, body: "本文",
        visibility: "organization", published_at: 1.minute.ago
      )

      Notification.create!(user: user, subject: subject, event: "announcement_published")
    end
end
