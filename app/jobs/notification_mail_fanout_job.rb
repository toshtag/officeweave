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

  def perform(notification_ids)
    Notification.where(id: notification_ids).find_each(&:deliver_by_mail)
  end
end
