require "browser_test_case"

# 主要な操作を、キーボードだけで完遂する。
#
# 受入条件 11 の証拠である。対象は docs/product/keyboard_flows.yml が持ち、
# 対応の漏れは test/configuration/keyboard_flow_coverage_test.rb が落とす。
#
# 使うのは Tab / Shift+Tab / Enter / Space / 文字の入力だけとする。
# click_link や fill_in のように要素を直接指す呼び出しは使わない。それらは
# 「押せたか」を見るが「到達できたか」を見ない。到達できない要素でも通る。
class KeyboardFlowsTest < BrowserTestCase
  include KeyboardNavigationTestHelper

  test "キーボードだけでログインする" do
    visit new_session_path
    tab_to(id: "email_address")
    type("taro@example.com")
    tab_to(id: "password")
    type("password-for-tests")
    tab_to(text: I18n.t("sessions.new.submit"))
    press_focused

    assert_text I18n.t("sessions.signed_in")
  end

  test "キーボードだけで外部の認証へ進む" do
    # 認可サーバーは立てない。送り出す入口へ到達し、押せることを見る。
    with_oidc_provider do
      visit new_session_path
      tab_to(text: I18n.t("sessions.oidc.submit"))

      assert_includes focused_label, I18n.t("sessions.oidc.submit")
    end
  end

  test "キーボードだけでパスワードを変える" do
    sign_in_as users(:taro)
    visit edit_password_path
    tab_to(id: "current_password")
    type("password-for-tests")
    tab_to(id: "user_password")
    type("a-new-long-enough-password")
    tab_to(id: "user_password_confirmation")
    type("a-new-long-enough-password")
    tab_to(text: I18n.t("passwords.edit.submit"))
    press_focused

    assert_text I18n.t("passwords.updated")
  end

  test "キーボードだけで端末を終わらせる" do
    sign_in_as users(:taro)
    visit logins_path
    skip_to_main
    tab_to(text: "この端末以外を終了する")
    press_focused

    assert_text I18n.t("logins.index.title")
  end

  test "キーボードだけで自分の設定を保存する" do
    sign_in_as users(:taro)
    visit settings_path
    skip_to_main
    tab_to(text: "保存する")
    press_focused

    assert_text I18n.t("settings.updated")
  end

  test "キーボードだけで利用者を追加する" do
    sign_in_as users(:taro)
    visit new_user_path
    tab_to(id: "user_name")
    type("キーボード 利用者")
    tab_to(id: "user_email_address")
    type("keyboard-user@example.com")
    tab_to(id: "user_password")
    type("a-long-enough-password")
    tab_to(id: "user_password_confirmation")
    type("a-long-enough-password")
    tab_to(text: "登録する")
    press_focused

    assert_text "キーボード 利用者"
  end

  test "キーボードだけで部門を作る" do
    sign_in_as users(:taro)
    visit new_department_path
    tab_to(id: "department_name")
    type("キーボード部")
    tab_to(id: "department_code")
    type("keyboard-dept")
    tab_to(text: "登録する")
    press_focused

    assert_text "キーボード部"
  end

  test "キーボードだけで書き出しを始める" do
    sign_in_as users(:taro)
    visit data_transfers_path
    skip_to_main
    tab_to(text: "利用者を書き出す")

    assert_includes focused_label, "利用者を書き出す"
  end

  test "キーボードだけで入口から移動する" do
    sign_in_as users(:taro)
    visit root_path
    skip_to_main
    tab_to(text: "お知らせ")
    press_focused

    assert_current_path announcements_path
  end

  test "キーボードだけでお知らせを公開する" do
    sign_in_as users(:taro)
    visit new_announcement_path
    tab_to(id: "announcement_title")
    type("キーボードのお知らせ")
    tab_to(id: "announcement_body")
    type("本文")
    tab_to(text: "登録する")
    press_focused

    assert_text "キーボードのお知らせ"
  end

  test "キーボードだけで予定を作る" do
    sign_in_as users(:taro)
    visit new_event_path
    tab_to(id: "event_title")
    type("キーボードの予定")
    tab_to(text: "登録する")
    press_focused

    assert_text "キーボードの予定"
  end

  test "キーボードだけで設備を作る" do
    sign_in_as users(:taro)
    visit new_resource_path
    tab_to(id: "resource_name")
    type("キーボードの設備")
    tab_to(id: "resource_code")
    type("keyboard-resource")
    tab_to(text: "登録する")
    press_focused

    assert_text "キーボードの設備"
  end

  test "キーボードだけで予約する" do
    sign_in_as users(:taro)
    visit new_reservation_path
    # 設備は選ばないと送信できない。ブラウザーが止める。
    tab_to(id: "reservation_resource_id")
    select_next
    tab_to(id: "reservation_purpose")
    type("キーボードの用途")
    tab_to(text: "登録する")
    press_focused

    assert_text "キーボードの用途"
  end

  test "キーボードだけで申請を提出する" do
    sign_in_as users(:taro)
    visit new_request_path
    tab_to(id: "request_request_type_id")
    select_next
    tab_to(id: "request_title")
    type("キーボードの申請")
    tab_to(id: "request_body")
    type("本文")
    tab_to(text: "登録する")
    press_focused

    assert_text "キーボードの申請"
  end

  test "キーボードだけで承認を委任する" do
    sign_in_as users(:approver)
    visit approval_delegations_path
    skip_to_main
    tab_to(id: "approval_delegation_delegate_id")
    # 選択欄は文字を送ると、その頭文字の候補へ移る。
    type(users(:taro).name[0])
    tab_to(text: "登録する")
    press_focused

    assert_text I18n.t("approval_delegations.created")
  end

  test "キーボードだけで文書を作る" do
    sign_in_as users(:taro)
    visit new_document_path
    tab_to(id: "document_title")
    type("キーボードの文書")
    tab_to(id: "document_body")
    type("本文")
    tab_to(text: "登録する")
    press_focused

    assert_text "キーボードの文書"
  end

  test "キーボードだけで通知を開く" do
    sign_in_as users(:taro)
    visit root_path
    skip_to_main
    # 通知は本文より前にある。読み飛ばさず、前から順にたどる。
    tab_to(text: "通知")
    press_focused

    assert_current_path notifications_path
  end

  test "キーボードだけで監査記録を絞り込む" do
    sign_in_as users(:taro)
    visit audit_events_path
    skip_to_main
    tab_to(text: "絞り込む")
    press_focused

    assert_current_path(/audit_events/)
  end

  test "キーボードだけで token を発行する" do
    sign_in_as users(:taro)
    visit api_tokens_path
    skip_to_main
    tab_to(id: "api_token_name")
    type("キーボードの token")
    tab_to(name: "api_token[scopes][]")
    toggle_focused
    tab_to(text: "発行する")
    press_focused

    assert_text I18n.t("api_tokens.created")
  end

  test "キーボードだけで送信先を登録する" do
    sign_in_as users(:taro)
    visit webhook_endpoints_path
    skip_to_main
    tab_to(id: "webhook_endpoint_name")
    type("キーボードの送信先")
    tab_to(id: "webhook_endpoint_url")
    type("https://example.com/hook")
    tab_to(text: "登録する")
    press_focused

    assert_text I18n.t("webhook_endpoints.created")
  end

  test "キーボードだけで表示言語を切り替える" do
    sign_in_as users(:taro)
    visit root_path
    tab_to(text: "English")
    press_focused

    assert_text "Announcements"
  end

  private
    # 認可サーバーは立てない。送り出す入口が出る設定にして、そこへ
    # キーボードで到達できることを見る。認可の往復そのものは
    # test/controllers/oidc_login_test.rb が確かめる。
    OIDC_ENVIRONMENT = {
      "AUTHENTICATION_PROVIDER" => "oidc",
      "OIDC_ISSUER" => "https://idp.example.com",
      "OIDC_CLIENT_ID" => "officeweave",
      "OIDC_CLIENT_SECRET" => "a-client-secret"
    }.freeze

    def with_oidc_provider
      original = OIDC_ENVIRONMENT.keys.index_with { |key| ENV[key] }
      OIDC_ENVIRONMENT.each { |key, value| ENV[key] = value }
      yield
    ensure
      original.each { |key, value| ENV[key] = value }
    end
end
