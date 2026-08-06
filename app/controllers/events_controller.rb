# 予定の参照と管理。
# 変更できるのは持ち主と管理者に限る。
class EventsController < ApplicationController
  records_no_audit :create, :update, :destroy,
                   reason: "業務の内容そのものであり、作成者と更新時刻を記録自身が持つ"

  before_action :set_event, only: %i[show edit update destroy]
  before_action :require_editable, only: %i[edit update destroy]

  def index
    @window = DateWindow.new(from: date_param(:from), to: date_param(:to))
    # 期間だけでは件数が決まらない。1 日に何件も積む組織では、1 か月ぶんが
    # そのまま読み込む量になる。期間の内側でも 1 ページずつ読む。
    @page = Pagination.new(
      Event.visible_to(Current.user)
        .starting_from(@window.from.beginning_of_day)
        .starting_before(@window.to.end_of_day)
        .chronological
        .includes(:owner),
      page: params[:page]
    )
    @events = @page.records
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
    # 繰り返しの指定は保存しない。指定の妥当性と各回の作成だけを受け持つ。
    @recurrence = Event::Recurrence.new(@event, frequency: params.dig(:event, :recurrence_frequency),
                                                repeat_until: params.dig(:event, :repeat_until))

    if @recurrence.save(participants: requested_participants)
      redirect_to @event, notice: t("events.created")
    else
      # 繰り返しの指定の誤りも、予定の誤りと同じ場所へ出す。
      @recurrence.errors.each { |error| @event.errors.add(error.attribute, error.message) }
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
    # 繰り返しの回は、この回以降をまとめて消せる。前の回は消さない。
    # 既に終わった回を、後からの操作で消さない。
    if params[:scope] == "following" && @event.recurring?
      @event.destroy_following
      notice = t("events.destroyed_following")
    else
      @event.destroy
      notice = t("events.destroyed")
    end

    redirect_to events_path, notice: notice, status: :see_other
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

    def invite_participants
      @event.invite(users: requested_participants, actor: Current.user)
    end

    # 参加者は自組織の有効な利用者だけから選ぶ。
    #
    # 画面は選択肢をその範囲に絞るが、受け入れ側に同じ判定がないと、
    # 選択肢に無い識別子をそのまま送れる。
    def requested_participants
      requested = params.dig(:event, :participant_ids).to_a.compact_blank

      current_organization.users.active.where(id: requested).to_a
    end
end
