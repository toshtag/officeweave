# お知らせの参照と管理。
# 参照は公開範囲に従い、作成と変更は管理者へ限定する。
class AnnouncementsController < ApplicationController
  before_action :require_administrator, only: %i[new create edit update destroy]
  before_action :set_announcement, only: %i[show edit update destroy]

  def index
    @announcements = Announcement.visible_to(Current.user).recent_first.includes(:author)
    @unread_ids = Announcement.visible_to(Current.user).unread_for(Current.user).pluck(:id).to_set
    @drafts = administrator? ? current_organization.announcements.where(published_at: nil).recent_first : []
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
      redirect_to @announcement, notice: t("announcements.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @announcement.update(announcement_params)
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
