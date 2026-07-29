# ログイン後の入口となる画面。
class HomeController < ApplicationController
  # 入口に並べる件数。多くしても最初の画面では読まれない。
  RECENT_ANNOUNCEMENT_COUNT = 5

  def show
    @announcements = Announcement.visible_to(Current.user).recent_first.limit(RECENT_ANNOUNCEMENT_COUNT)
  end
end
