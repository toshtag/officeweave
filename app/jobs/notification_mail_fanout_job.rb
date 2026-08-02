# まとめて作られた通知の、メールの送信を積む。
#
# 受け手ごとの投入を要求の外へ出すために置く。組織全体へのお知らせでは、
# 受け手の人数だけキューへの書き込みが起きる。要求の中で行うと、その分だけ
# 応答が遅れる。
#
# 送信そのものは行わない。通知 1 件につき 1 つの送信のジョブを積み、
# やり直しは従来どおり NotificationMailDeliveryJob が受け持つ。
# ここで送ると、1 通の失敗が残り全部のやり直しを巻き込む。
#
# 消えた通知は飛ばす。積んでから実行されるまでの間に、対象のお知らせや
# 申請が取り消され得る。
class NotificationMailFanoutJob < ApplicationJob
  queue_as :default

  # 利用者と配信設定は batch ごとにまとめて読む。先読みしないと、
  # 通知 1 件につき利用者を 1 回、その配信設定を 1 回引く。件数は受け手の
  # 人数で決まるため、そのまま利用者数に比例した往復になる。
  def perform(notification_ids)
    Notification.where(id: notification_ids)
                .includes(user: :notification_preferences)
                .find_each(&:deliver_by_mail)
  end
end
