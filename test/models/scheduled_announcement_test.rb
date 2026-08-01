require "test_helper"

# 公開日時を先に設定したお知らせの契約を固定する。
#
# 公開の知らせは、作成や更新の時点ではなく、公開日時が来た時点で送る。
# 作成の時点で送ると、まだ読めないお知らせの知らせだけが先に届く。
class ScheduledAnnouncementTest < ActiveSupport::TestCase
  setup do
    @scheduled = announcements(:scheduled)
  end

  test "公開待ちのお知らせは公開済みに含まれない" do
    assert_not_predicate @scheduled, :published?
    assert_not_includes Announcement.published, @scheduled
  end

  test "公開待ちのお知らせを公開待ちとして絞り込める" do
    assert_includes Announcement.scheduled, @scheduled
    assert_not_includes Announcement.scheduled, announcements(:draft)
    assert_not_includes Announcement.scheduled, announcements(:company_wide)
  end

  test "公開日時が来たものだけが知らせの対象になる" do
    assert_not_includes Announcement.awaiting_publication_notice, @scheduled

    travel_to @scheduled.published_at + 1.minute do
      assert_includes Announcement.awaiting_publication_notice, @scheduled
    end
  end

  test "知らせ済みのものは対象にならない" do
    travel_to @scheduled.published_at + 1.minute do
      @scheduled.notify_publication

      assert_not_includes Announcement.awaiting_publication_notice, @scheduled
    end
  end

  test "公開日時が来ると対象の利用者へ知らせる" do
    travel_to @scheduled.published_at + 1.minute do
      assert_difference -> { Notification.where(subject: @scheduled).count }, recipient_count do
        @scheduled.notify_publication
      end
    end
  end

  test "同じお知らせを二度知らせない" do
    travel_to @scheduled.published_at + 1.minute do
      @scheduled.notify_publication

      assert_no_difference -> { Notification.where(subject: @scheduled).count } do
        assert_not @scheduled.notify_publication
      end
    end
  end

  test "公開日時が来ていないうちは知らせない" do
    assert_no_difference -> { Notification.where(subject: @scheduled).count } do
      assert_not @scheduled.notify_publication
    end

    assert_nil @scheduled.reload.notified_at
  end

  test "下書きは知らせない" do
    assert_not announcements(:draft).notify_publication
  end

  test "作成者自身へは知らせない" do
    travel_to @scheduled.published_at + 1.minute do
      @scheduled.notify_publication

      assert_empty Notification.where(subject: @scheduled, user_id: @scheduled.author_id)
    end
  end

  test "定期実行は公開日時の来たものをまとめて知らせる" do
    travel_to @scheduled.published_at + 1.minute do
      assert_difference -> { Notification.where(subject: @scheduled).count }, recipient_count do
        PublishScheduledAnnouncementsJob.perform_now
      end

      assert_not_nil @scheduled.reload.notified_at
    end
  end

  test "定期実行を繰り返しても知らせは増えない" do
    travel_to @scheduled.published_at + 1.minute do
      PublishScheduledAnnouncementsJob.perform_now

      assert_no_difference -> { Notification.where(subject: @scheduled).count } do
        PublishScheduledAnnouncementsJob.perform_now
      end
    end
  end

  private
    # 作成者を除いた、知らせが届く利用者の数。
    def recipient_count
      @scheduled.recipients.where.not(id: @scheduled.author_id).count
    end
end
