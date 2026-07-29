require "application_system_test_case"

class ReservationsTest < ApplicationSystemTestCase
  setup do
    # hanako は表示言語を英語に設定している。画面の文言もその言語で確認する。
    @locale = :en
    @base = 1.day.from_now.change(hour: 9)
  end

  test "JavaScript なしで予約でき、重なる予約は理由が示される" do
    sign_in_as users(:hanako)

    visit reservations_path
    click_link I18n.t("reservations.index.new", locale: @locale)

    book(from: @base.change(hour: 13), to: @base.change(hour: 14), purpose: "面談")

    assert_text I18n.t("reservations.created", locale: @locale)

    click_link I18n.t("reservations.index.new", locale: @locale)
    book(from: @base.change(hour: 13, min: 30), to: @base.change(hour: 14, min: 30))

    assert_selector ".error-summary"
  end

  test "受付を停止している設備・備品は選べない" do
    sign_in_as users(:taro)

    visit new_reservation_path

    assert_no_selector "option", text: resources(:retired_projector).name
  end

  private
    def book(from:, to:, purpose: nil)
      select resources(:meeting_room_a).name, from: Reservation.human_attribute_name(:resource, locale: @locale)
      fill_in Reservation.human_attribute_name(:starts_at, locale: @locale), with: from.strftime("%Y-%m-%dT%H:%M")
      fill_in Reservation.human_attribute_name(:ends_at, locale: @locale), with: to.strftime("%Y-%m-%dT%H:%M")
      fill_in Reservation.human_attribute_name(:purpose, locale: @locale), with: purpose if purpose
      click_button I18n.t("helpers.submit.create", locale: @locale,
                          model: Reservation.model_name.human(locale: @locale))
    end
end
