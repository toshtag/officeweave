require "test_helper"

# 複数の利用者へまとめて知らせる経路。
#
# 受け手の人数は組織の規模で決まる。人数に比例して問い合わせが増えると、
# 組織全体へのお知らせ 1 件の公開が、そのまま利用者数に比例した待ち時間になる。
class NotificationBatchDeliveryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper
  include ActionMailer::TestHelper
  include QueryCountTestHelper

  # 受け手の人数だけを変えて、同じ操作を 2 回数える。
  # 絶対の件数を期待値へ書くと、無関係な変更で失敗する。ここで確かめたいのは
  # 件数そのものではなく、人数によって増えないことである。
  test "お知らせの公開で出る問い合わせが、受け手の人数で増えない" do
    few = build_announcement("受け手の少ないお知らせ")
    few_count = count_queries { few.notify_publication }

    add_recipients(30)

    many = build_announcement("受け手の多いお知らせ")
    many_count = count_queries { many.notify_publication }

    assert_equal few_count, many_count
  end

  # キューへの書き込みも問い合わせである。受け手ごとに 1 件ずつ積むと、
  # 人数に比例した書き込みが要求の中で起きる。
  test "お知らせの公開で積むジョブが、受け手の人数で増えない" do
    few = build_announcement("受け手の少ないお知らせ")
    few_count = count_enqueued_jobs { few.notify_publication }

    add_recipients(30)

    many = build_announcement("受け手の多いお知らせ")
    many_count = count_enqueued_jobs { many.notify_publication }

    assert_equal few_count, many_count
  end

  test "受け手が増えても、作られる通知は受け手のぶんだけになる" do
    add_recipients(5)
    announcement = build_announcement("全員への連絡")

    assert_difference -> { Notification.count }, announcement.recipients.count - 1 do
      announcement.notify_publication
    end
  end

  test "作成者には通知しない" do
    announcement = build_announcement("全員への連絡")
    announcement.notify_publication

    assert_empty Notification.where(user: users(:taro), subject: announcement)
  end

  test "同じお知らせを二度知らせても通知は増えない" do
    announcement = build_announcement("全員への連絡")
    announcement.notify_publication

    assert_no_difference -> { Notification.count } do
      Notification.deliver_to_all(users: announcement.recipients.where.not(id: announcement.author_id),
                                  subject: announcement, event: "announcement_published")
    end
  end

  # 1 件ずつ作ると、境界を越えた受け手にぶつかるまでの分だけが作られる。
  # まとめて書き込む経路では、作る前に全件を確かめる。
  test "別組織の利用者が混ざっている場合は、1 件も通知を作らない" do
    assert_no_difference -> { Notification.count } do
      assert_raises ActiveRecord::RecordInvalid do
        Notification.deliver_to_all(users: [ users(:hanako), users(:outsider) ],
                                    subject: announcements(:company_wide),
                                    event: "announcement_published")
      end
    end
  end

  test "無効にされた利用者へは通知しない" do
    users(:hanako).deactivate!
    announcement = build_announcement("全員への連絡")

    announcement.notify_publication

    assert_empty Notification.where(user: users(:hanako), subject: announcement)
  end

  test "メールは受け手のぶんだけ届く" do
    announcement = build_announcement("全員への連絡")
    expected = announcement.recipients.count - 1

    assert_emails expected do
      perform_enqueued_jobs { announcement.notify_publication }
    end
  end

  test "受け取らない設定の利用者へはメールを送らない" do
    users(:hanako).notification_preferences.create!(event: "announcement_published", mail_enabled: false)
    announcement = build_announcement("全員への連絡")
    expected = announcement.recipients.count - 2

    assert_emails expected do
      perform_enqueued_jobs { announcement.notify_publication }
    end

    assert_not_empty Notification.where(user: users(:hanako), subject: announcement)
  end

  private
    def count_enqueued_jobs
      before = enqueued_jobs.size
      yield
      enqueued_jobs.size - before
    end

    def build_announcement(title)
      organizations(:main).announcements.create!(
        author: users(:taro), title: title, body: "本文",
        visibility: "organization", published_at: 1.minute.ago
      )
    end

    # 照合の速さはテストの実行時間に直に効く。固定のデータと同じ最小の負荷を使う。
    def add_recipients(count)
      digest = BCrypt::Password.create("password-for-tests", cost: BCrypt::Engine::MIN_COST)

      count.times do |index|
        organizations(:main).users.create!(
          name: "受け手 #{index}", email_address: "recipient#{index}@example.com",
          password_digest: digest
        )
      end
    end
end
