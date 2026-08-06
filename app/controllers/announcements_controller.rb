# お知らせの参照と管理。
# 参照は公開範囲に従い、作成と変更は管理者へ限定する。
class AnnouncementsController < ApplicationController
  # 下書きと公開待ちに並べる件数。
  #
  # 本体の一覧と違い、作った本人が確認するための区分である。溜まる性質の
  # ものではないが、上限を置かないと、放置した組織でだけ重くなる。
  SIDE_LIST_COUNT = 25

  records_no_audit :create, :update, :destroy,
                   reason: "業務の内容そのものであり、作成者と更新時刻を記録自身が持つ。監査へ写すと、題名と本文が監査の詳細へ流れる"

  before_action :require_administrator, only: %i[new create edit update destroy]
  before_action :set_announcement, only: %i[show edit update destroy]

  def index
    @query = params[:query]
    visible = Announcement.visible_to(Current.user).search(@query)

    @page = Pagination.new(listed(visible.recent_first), page: params[:page])
    @announcements = @page.records
    # 未読の判定は、画面へ並べる分だけで足りる。参照できる未読を全件取り出すと、
    # 1 ページの表示のために蓄積した全件を読むことになる。
    @unread_ids = visible.unread_for(Current.user)
                         .where(id: @announcements.map(&:id)).pluck(:id).to_set
    @drafts = listed(manageable.where(published_at: nil).recent_first).limit(SIDE_LIST_COUNT).to_a
    # 公開待ちは公開済みにも下書きにも入らない。区分を分けないと、
    # 作成した管理者自身が確認も訂正も取り消しもできない。
    @scheduled = listed(manageable.scheduled.reorder(published_at: :asc, id: :asc))
                   .limit(SIDE_LIST_COUNT).to_a
  end

  def show
    # 参照した時点で既読とする。
    # 読んだかどうかを利用者に申告させると、記録が実態と合わなくなる。
    @announcement.mark_as_read_by(Current.user) if @announcement.published?
  end

  def new
    @announcement = current_organization.announcements.new(visibility: "organization")
  end

  def edit
  end

  def create
    @announcement = current_organization.announcements.new(announcement_params)
    @announcement.author = Current.user

    if @announcement.save
      # 公開待ちの場合はここでは送らない。公開日時が来た時点で
      # 定期実行が送る。作成の時点で送ると、まだ読めないお知らせの
      # 知らせだけが先に届く。
      @announcement.notify_publication
      redirect_to @announcement, notice: t("announcements.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @announcement.update(announcement_params)
      @announcement.notify_publication
      redirect_to @announcement, notice: t("announcements.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @announcement.destroy

    redirect_to announcements_path, notice: t("announcements.destroyed"), status: :see_other
  end

  private
    # 一覧へ並べる区分の読み込み方。
    #
    # 3 つの区分はいずれも作成者の氏名を表示する。区分ごとに書くと、
    # 区分を足したときに先読みの有無が分かれ、片方だけ件数だけ問い合わせが
    # 出る状態になる。実際、公開済みだけが先読みを持っていた。
    def listed(announcements)
      announcements.includes(:author)
    end

    # 管理者だけが扱える区分。一般利用者には空の一覧を返す。
    def manageable
      administrator? ? current_organization.announcements : Announcement.none
    end

    # 管理者は下書きも参照できる。それ以外は公開範囲に入るものだけを扱う。
    def set_announcement
      scope = administrator? ? current_organization.announcements : Announcement.visible_to(Current.user)
      @announcement = scope.find(params[:id])
    end

    def announcement_params
      attributes = params.expect(
        announcement: [ :title, :body, :visibility, :published_at, { department_ids: [] } ]
      )

      # 組織全体へ公開する場合、部門の指定は意味を持たないため取り除く。
      attributes[:department_ids] = [] unless attributes[:visibility] == "departments"
      attributes
    end
end
