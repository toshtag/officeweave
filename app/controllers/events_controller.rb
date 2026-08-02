# 予定の参照と管理。
# 変更できるのは持ち主と管理者に限る。
class EventsController < ApplicationController
  before_action :set_event, only: %i[show edit update destroy]
  before_action :require_editable, only: %i[edit update destroy]

  def index
    @from = date_param(:from) || Date.current
    @events = Event.visible_to(Current.user)
                   .starting_from(@from.beginning_of_day)
                   .chronological
                   .includes(:owner)
  rescue TimeParameters::InvalidParameter
    redirect_to events_path
  end

  def show
  end

  def new
    @event = current_organization.events.new(
      visibility: "organization",
      starts_at: Time.current.beginning_of_hour + 1.hour,
      ends_at: Time.current.beginning_of_hour + 2.hours
    )
  end

  def edit
  end

  def create
    @event = current_organization.events.new(event_params)
    @event.owner = Current.user

    if @event.save
      invite_participants
      redirect_to @event, notice: t("events.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @event.update(event_params)
      invite_participants
      redirect_to @event, notice: t("events.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @event.destroy

    redirect_to events_path, notice: t("events.destroyed"), status: :see_other
  end

  private
    def set_event
      @event = Event.visible_to(Current.user).find(params[:id])
    end

    def require_editable
      return if @event.editable_by?(Current.user)

      render "shared/forbidden", status: :forbidden, formats: :html
    end

    def event_params
      attributes = params.expect(
        event: [ :title, :description, :starts_at, :ends_at, :all_day, :visibility,
                { department_ids: [], participant_ids: [] } ]
      )

      attributes[:department_ids] = [] unless attributes[:visibility] == "departments"
      # 参加者は保存のあとで指名する。指名した相手へだけ知らせるためである。
      attributes.except(:participant_ids)
    end

    # 参加者は自組織の有効な利用者だけから選ぶ。
    #
    # 画面は選択肢をその範囲に絞るが、受け入れ側に同じ判定がないと、
    # 選択肢に無い識別子をそのまま送れる。
    def invite_participants
      requested = params.dig(:event, :participant_ids).to_a.compact_blank

      @event.invite(users: current_organization.users.active.where(id: requested).to_a,
                    actor: Current.user)
    end
end
