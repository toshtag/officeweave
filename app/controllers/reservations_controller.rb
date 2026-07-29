# 設備・備品の予約。
class ReservationsController < ApplicationController
  before_action :set_reservation, only: %i[destroy]

  def index
    @from = params[:from].present? ? Date.parse(params[:from]) : Date.current
    @reservations = current_organization.reservations
                                        .starting_from(@from.beginning_of_day)
                                        .chronological
                                        .includes(:resource, :reserver)
  rescue Date::Error
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

  def destroy
    unless @reservation.cancelable_by?(Current.user)
      return render "shared/forbidden", status: :forbidden, formats: :html
    end

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

    def reservation_params
      params.expect(reservation: %i[resource_id event_id starts_at ends_at purpose])
    end
end
