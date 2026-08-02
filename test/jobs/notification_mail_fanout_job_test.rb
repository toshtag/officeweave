require "test_helper"

# まとめて作られた通知を、メールの送信へ展開する経路。
#
# 通知の件数は組織の規模で決まる。#119 で、その作成は利用者の要求の外へ移した。
# 移した先で件数に比例した問い合わせを出すと、待たされるのが利用者ではなく
# worker になるだけで、量そのものは減らない。
class NotificationMailFanoutJobTest < ActiveJob::TestCase
  include QueryCountTestHelper

  # 通知の件数だけを変えて、同じ展開を 2 回数える。
  # 絶対の件数を期待値へ書くと、無関係な変更で失敗する。ここで確かめたいのは
  # 件数そのものではなく、通知の数によって増えないことである。
  test "展開で出る問い合わせが、通知の数で増えない" do
    few = build_notifications(5)
    few_count = count_queries { NotificationMailFanoutJob.perform_now(few) }

    many = build_notifications(30)
    many_count = count_queries { NotificationMailFanoutJob.perform_now(many) }

    assert_equal few_count, many_count
  end

  test "メールを受け取らない設定の利用者へは積まない" do
    disabled = create_recipient("disabled@example.com")
    disabled.notification_preferences.create!(event: "announcement_published", mail_enabled: false)

    assert_no_enqueued_jobs only: NotificationMailDeliveryJob do
      NotificationMailFanoutJob.perform_now(notification_ids_for([ disabled ]))
    end
  end

  # 設定を持たない利用者は受け取る。まとめ読みでは、その利用者について
  # 行が 1 件も返らない。無いことを「受け取らない」と取り違えると、
  # 既定で通知が届かなくなる。
  test "配信設定を持たない利用者へは積む" do
    recipient = create_recipient("default@example.com")

    assert_enqueued_jobs 1, only: NotificationMailDeliveryJob do
      NotificationMailFanoutJob.perform_now(notification_ids_for([ recipient ]))
    end
  end

  # 設定は種類ごとに持つ。別の種類を無効にしただけの利用者へは送る。
  test "別の種類を無効にした設定は、この種類の判定に影響しない" do
    recipient = create_recipient("other-event@example.com")
    recipient.notification_preferences.create!(event: "request_submitted", mail_enabled: false)

    assert_enqueued_jobs 1, only: NotificationMailDeliveryJob do
      NotificationMailFanoutJob.perform_now(notification_ids_for([ recipient ]))
    end
  end

  # 積んでから実行までの間に、対象のお知らせや申請が取り消され得る。
  test "消えた通知は飛ばす" do
    recipient = create_recipient("gone@example.com")
    ids = notification_ids_for([ recipient ])
    Notification.where(id: ids).delete_all

    assert_no_enqueued_jobs only: NotificationMailDeliveryJob do
      NotificationMailFanoutJob.perform_now(ids)
    end
  end

  # 1 通の失敗が残り全部のやり直しを巻き込まないよう、送信は通知ごとに積む。
  test "通知 1 件につき 1 つの送信を積む" do
    recipients = 3.times.map { |index| create_recipient("each#{index}@example.com") }

    assert_enqueued_jobs 3, only: NotificationMailDeliveryJob do
      NotificationMailFanoutJob.perform_now(notification_ids_for(recipients))
    end
  end

  private
    def announcement
      @announcement ||= organizations(:main).announcements.create!(
        author: users(:taro), title: "展開の確認", body: "本文",
        visibility: "organization", published_at: 1.minute.ago
      )
    end

    # 照合の速さはテストの実行時間に直に効く。固定のデータと同じ最小の負荷を使う。
    def create_recipient(email_address)
      organizations(:main).users.create!(
        name: email_address, email_address: email_address,
        password_digest: BCrypt::Password.create("password-for-tests", cost: BCrypt::Engine::MIN_COST)
      )
    end

    def notification_ids_for(users)
      Notification.deliver_to_all(users: users, subject: announcement,
                                  event: "announcement_published")
    end

    # 受け取る利用者と受け取らない利用者を混ぜる。まとめ読みが、設定のある側と
    # 無い側のどちらかだけで成り立っていても気付けるようにする。
    def build_notifications(count)
      recipients = count.times.map do |index|
        user = create_recipient("fanout#{count}-#{index}@example.com")
        user.notification_preferences.create!(event: "announcement_published",
                                              mail_enabled: index.even?)
        user
      end

      notification_ids_for(recipients)
    end
end
