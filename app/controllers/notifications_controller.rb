# 自分宛の通知の一覧と、通知からの移動。
class NotificationsController < ApplicationController
  def index
    @notifications = Current.user.notifications.recent_first.includes(:subject)
  end

  # 通知を開いたら既読にして、対象の画面へ送る。
  # 一覧で読んだことにすると、実際には見ていない通知まで消える。
  def show
    notification = Current.user.notifications.find(params[:id])
    notification.mark_as_read

    redirect_to notification_target_path(notification)
  end

  private
    def notification_target_path(notification)
      case notification.subject
      when Announcement then announcement_path(notification.subject)
      when Request then request_path(notification.subject)
      else root_path
      end
    end
end
