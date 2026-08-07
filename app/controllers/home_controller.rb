# ログイン後の入口となる画面。
class HomeController < ApplicationController
  # 入口に並べる件数。多くしても最初の画面では読まれない。
  RECENT_ANNOUNCEMENT_COUNT = 5
  RECENT_REQUEST_COUNT = 5

  def show
    visible = Announcement.visible_to(Current.user)

    @announcements = visible.recent_first.limit(RECENT_ANNOUNCEMENT_COUNT).to_a

    # 未読の判定は、画面へ並べる分だけで足りる。参照できる未読を全件取り出すと、
    # 表示する数件のために蓄積した全件を読むことになる。読まない利用者ほど重くなる。
    unread = visible.unread_for(Current.user)
    @unread_ids = unread.where(id: @announcements.map(&:id)).pluck(:id).to_set

    # 件数は数え上げで求める。取り出した集合の大きさから求めると、
    # 数だけを表示するために識別子を全件持つことになる。
    @unread_count = unread.count

    awaiting = Request.awaiting_decision_by(Current.user)

    # 件数は数え上げで求める。取り出した集合の大きさから求めると、
    # 数だけを表示するために対象の申請を全件読むことになる。
    @awaiting_count = awaiting.count
    @awaiting_requests = listed(awaiting).includes(:applicant).to_a

    # 所属部門は階層まで表示する。1 件ずつ上位をたどると、所属の数と
    # 階層の深さの積だけ問い合わせが出る。
    @departments = Department.with_ancestors(Current.user.departments.ordered)

    @open_requests = listed(Request.visible_to(Current.user)
                                   .applied_by(Current.user)
                                   .with_status(%w[draft pending returned])).to_a
  end

  private
    # 入口へ並べる分だけを、表示に使う列で読む。
    # 上限を置かないと、ためている利用者ほど最初の画面が重くなる。
    def listed(requests)
      requests.recent_first.listed.limit(RECENT_REQUEST_COUNT)
    end
end
