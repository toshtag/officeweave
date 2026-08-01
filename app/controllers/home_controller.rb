# ログイン後の入口となる画面。
class HomeController < ApplicationController
  # 入口に並べる件数。多くしても最初の画面では読まれない。
  RECENT_ANNOUNCEMENT_COUNT = 5

  def show
    visible = Announcement.visible_to(Current.user)

    @announcements = visible.recent_first.limit(RECENT_ANNOUNCEMENT_COUNT)
    @unread_ids = visible.unread_for(Current.user).pluck(:id).to_set
    @unread_count = @unread_ids.size

    @awaiting_requests = Request.awaiting_decision_by(Current.user)
                                .recent_first
                                .includes(:request_type, :applicant)
    # 所属部門は階層まで表示する。1 件ずつ上位をたどると、所属の数と
    # 階層の深さの積だけ問い合わせが出る。
    @departments = Department.with_ancestors(Current.user.departments.ordered)

    @open_requests = Request.visible_to(Current.user)
                            .applied_by(Current.user)
                            .with_status(%w[draft pending returned])
                            .recent_first
  end
end
