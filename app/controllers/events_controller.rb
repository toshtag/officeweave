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
      redirect_to @event, notice: t("events.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @event.update(event_params)
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
        event: [ :title, :description, :starts_at, :ends_at, :all_day, :visibility, { department_ids: [] } ]
      )

      attributes[:department_ids] = [] unless attributes[:visibility] == "departments"
      attributes
    end
end
