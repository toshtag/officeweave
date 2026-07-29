require "application_system_test_case"

# 導入から日常業務までを、画面の操作だけで一通り通す。
#
# 個別の機能は各テストで確認している。ここでは、
# 機能をまたいだときに前提が崩れないことを確認する。
class EndToEndTest < ApplicationSystemTestCase
  test "組織の準備から日常業務までを JavaScript なしで通せる" do
    prepare_organization
    share_announcement
    schedule_event_and_reservation
    submit_and_approve_request
    publish_and_search_document
  end

  private
    # 管理者が組織構造を整える。
    def prepare_organization
      sign_in_as users(:taro)

      visit departments_path
      click_link I18n.t("departments.index.new")
      fill_in Department.human_attribute_name(:name), with: "総務部"
      fill_in Department.human_attribute_name(:code), with: "general"
      click_button I18n.t("helpers.submit.create")

      assert_text I18n.t("departments.created")

      select users(:hanako).name, from: User.model_name.human
      click_button I18n.t("memberships.new.submit")

      assert_text I18n.t("memberships.created")
    end

    # 部門を指定したお知らせが、所属者にだけ届く。
    def share_announcement
      visit new_announcement_path
      fill_in Announcement.human_attribute_name(:title), with: "総務部への連絡"
      fill_in Announcement.human_attribute_name(:body), with: "備品の棚卸しを行います。"
      choose I18n.t("announcements.visibilities.departments")
      check "総務部"
      fill_in Announcement.human_attribute_name(:published_at),
              with: Time.current.strftime("%Y-%m-%dT%H:%M")
      click_button I18n.t("helpers.submit.create")

      assert_text I18n.t("announcements.created")

      # 所属していない利用者には見えない。
      as(users(:outsider_free)) do
        visit announcements_path

        assert_no_text "総務部への連絡"
      end
    end

    # 予定と、それに結びつく予約を登録する。
    def schedule_event_and_reservation
      visit new_event_path
      fill_in Event.human_attribute_name(:title), with: "棚卸しの打ち合わせ"
      fill_in Event.human_attribute_name(:starts_at),
              with: 1.day.from_now.change(hour: 15).strftime("%Y-%m-%dT%H:%M")
      fill_in Event.human_attribute_name(:ends_at),
              with: 1.day.from_now.change(hour: 16).strftime("%Y-%m-%dT%H:%M")
      click_button I18n.t("helpers.submit.create")

      assert_text I18n.t("events.created")

      visit new_reservation_path
      select resources(:meeting_room_b).name, from: Reservation.human_attribute_name(:resource)
      fill_in Reservation.human_attribute_name(:starts_at),
              with: 1.day.from_now.change(hour: 15).strftime("%Y-%m-%dT%H:%M")
      fill_in Reservation.human_attribute_name(:ends_at),
              with: 1.day.from_now.change(hour: 16).strftime("%Y-%m-%dT%H:%M")
      select "棚卸しの打ち合わせ", from: Reservation.human_attribute_name(:event)
      click_button I18n.t("helpers.submit.create")

      assert_text I18n.t("reservations.created")

      # 同じ時間帯は二重に取れない。
      visit new_reservation_path
      select resources(:meeting_room_b).name, from: Reservation.human_attribute_name(:resource)
      fill_in Reservation.human_attribute_name(:starts_at),
              with: 1.day.from_now.change(hour: 15, min: 30).strftime("%Y-%m-%dT%H:%M")
      fill_in Reservation.human_attribute_name(:ends_at),
              with: 1.day.from_now.change(hour: 16, min: 30).strftime("%Y-%m-%dT%H:%M")
      click_button I18n.t("helpers.submit.create")

      assert_selector ".error-summary"
    end

    # 申請を出し、承認まで通す。
    def submit_and_approve_request
      as(users(:hanako)) do
        visit new_request_path
        select request_types(:expense).name, from: Request.human_attribute_name(:request_type, locale: :en)
        fill_in Request.human_attribute_name(:title, locale: :en), with: "棚卸し用品の購入"
        click_button submit_label(:create, Request)

        assert_text I18n.t("requests.created", locale: :en)

        click_button I18n.t("requests.submit", locale: :en)

        assert_text I18n.t("requests.statuses.pending", locale: :en)
      end

      visit requests_path
      # 件数は他の申請の状況で変わるため、名称の部分で選ぶ。
      find(:link, text: /#{Regexp.escape(I18n.t("requests.index.scopes.awaiting", count: 0))}/).click
      click_link "棚卸し用品の購入"
      fill_in I18n.t("request_decisions.comment"), with: "確認しました。"
      click_button I18n.t("request_decisions.approve")

      assert_text I18n.t("request_decisions.approved")
      assert_text I18n.t("requests.statuses.approved")
    end

    # 文書を公開し、検索で見つけられる。
    def publish_and_search_document
      visit new_document_path
      fill_in Document.human_attribute_name(:title), with: "棚卸しの手順"
      fill_in Document.human_attribute_name(:body), with: "備品の数を数え、台帳と照合します。"
      click_button I18n.t("helpers.submit.create")

      assert_text I18n.t("documents.created")

      visit documents_path
      fill_in I18n.t("documents.index.query"), with: "台帳と照合"
      click_button I18n.t("documents.index.search")

      assert_text "棚卸しの手順"
      assert_no_text documents(:travel_rule).title
    end

    def as(user)
      click_button sign_out_label
      sign_in_as user
      yield
      click_button sign_out_label
      sign_in_as users(:taro)
    end

    # 表示言語は利用者ごとに異なるため、画面に出ているほうを使う。
    def sign_out_label
      japanese = I18n.t("sessions.sign_out")

      page.has_button?(japanese) ? japanese : I18n.t("sessions.sign_out", locale: :en)
    end

    def submit_label(action, model)
      I18n.t("helpers.submit.#{action}", locale: :en, model: model.model_name.human(locale: :en))
    end
end
