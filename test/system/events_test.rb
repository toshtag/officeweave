require "application_system_test_case"

class EventsTest < ApplicationSystemTestCase
  test "JavaScript なしで予定を作成できる" do
    sign_in_as users(:taro)

    visit events_path
    click_link I18n.t("events.index.new")

    fill_in Event.human_attribute_name(:title), with: "設備の点検"
    fill_in Event.human_attribute_name(:starts_at), with: 1.day.from_now.change(hour: 9).strftime("%Y-%m-%dT%H:%M")
    fill_in Event.human_attribute_name(:ends_at), with: 1.day.from_now.change(hour: 10).strftime("%Y-%m-%dT%H:%M")
    choose I18n.t("events.visibilities.private")
    click_button I18n.t("helpers.submit.create")

    assert_text I18n.t("events.created")
    assert_text "設備の点検"
    assert_text I18n.t("events.visibilities.private")
  end

  test "終了が開始より前だと理由が示される" do
    sign_in_as users(:taro)

    visit new_event_path
    fill_in Event.human_attribute_name(:title), with: "打ち合わせ"
    fill_in Event.human_attribute_name(:starts_at), with: 1.day.from_now.change(hour: 10).strftime("%Y-%m-%dT%H:%M")
    fill_in Event.human_attribute_name(:ends_at), with: 1.day.from_now.change(hour: 9).strftime("%Y-%m-%dT%H:%M")
    click_button I18n.t("helpers.submit.create")

    assert_selector ".error-summary"
  end

  test "表示開始日で絞り込める" do
    sign_in_as users(:taro)

    visit events_path
    assert_no_text events(:past_event).title

    fill_in I18n.t("events.index.from"), with: 10.days.ago.to_date.strftime("%Y-%m-%d")
    click_button I18n.t("events.index.filter")

    assert_text events(:past_event).title
  end
end
