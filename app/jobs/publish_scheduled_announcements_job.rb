# 公開日時が来たお知らせを知らせる。
#
# 公開は日時の到来で成立するため、誰かの操作を待たずに知らせる必要がある。
# 定期実行で登録する（config/recurring.yml を参照）。
#
# 1 件の失敗で残りを止めない。知らせ済みの記録は模型が持つため、
# 次の実行が取りこぼした分だけを拾う。
class PublishScheduledAnnouncementsJob < ApplicationJob
  queue_as :default

  def perform
    Announcement.awaiting_publication_notice.find_each do |announcement|
      announcement.notify_publication
    rescue StandardError => error
      Rails.error.report(error, handled: true, context: { announcement_id: announcement.id })
    end
  end
end
