# 設備・備品の予約。
class ReservationsController < ApplicationController
  before_action :set_reservation, only: %i[edit update destroy]
  # 変更と取り消しは、同じ範囲の利用者へ認める。
  before_action :require_modifiable, only: %i[edit update destroy]

  def index
    @from = date_param(:from) || Date.current
    @reservations = current_organization.reservations
                                        .starting_from(@from.beginning_of_day)
                                        .chronological
                                        .includes(:resource, :reserver)
  rescue TimeParameters::InvalidParameter
    redirect_to reservations_path
  end

  def new
    @reservation = build_reservation
  end

  def create
    @reservation = build_reservation(reservation_params)
    @reservation.reserver = Current.user

    if @reservation.save_with_overlap_check
      redirect_to reservations_path, notice: t("reservations.created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    # 予約の変更は、取り消して作り直す形にしない。作り直すあいだに、
    # 同じ時間帯を別の利用者が取れる。
    if @reservation.update_with_overlap_check(reservation_params)
      redirect_to reservations_path, notice: t("reservations.updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @reservation.destroy

    redirect_to reservations_path, notice: t("reservations.destroyed"), status: :see_other
  end

  private
    def build_reservation(attributes = {})
      current_organization.reservations.new(
        {
          starts_at: Time.current.beginning_of_hour + 1.hour,
          ends_at: Time.current.beginning_of_hour + 2.hours
        }.merge(attributes)
      )
    end

    def set_reservation
      @reservation = current_organization.reservations.find(params[:id])
    end

    def require_modifiable
      return if @reservation.modifiable_by?(Current.user)

      render "shared/forbidden", status: :forbidden, formats: :html
    end

    def reservation_params
      params.expect(reservation: %i[resource_id event_id starts_at ends_at purpose])
    end
end
