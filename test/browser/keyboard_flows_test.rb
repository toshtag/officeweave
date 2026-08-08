require "browser_test_case"
require "timeout"
require_relative "../test_helpers/local_certificate_test_helper"
require_relative "../test_helpers/local_http_server_test_helper"
require_relative "../test_helpers/oidc_provider_test_helper"

# 主要な操作を、キーボードだけで完遂する。
#
# 共通条件 `keyboard` の証拠である。対象は docs/product/keyboard_flows.yml が持ち、
# 対応の漏れは test/configuration/keyboard_flow_coverage_test.rb が落とす。
#
# 使うのは Tab / Shift+Tab / Enter / Space / 文字の入力だけとする。
# click_link や fill_in のように要素を直接指す呼び出しは使わない。それらは
# 「押せたか」を見るが「到達できたか」を見ない。到達できない要素でも通る。
class KeyboardFlowsTest < BrowserTestCase
  include KeyboardNavigationTestHelper
  include LocalHttpServerTestHelper
  include OidcProviderTestHelper

  # 記録へ現れるまで待つ上限。退行を停止ではなく失敗として受け取る。
  LOG_WAIT = 10

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
    # 認可の往復そのものは test/controllers/oidc_login_test.rb が持つ。
    # ここで見るのは、入口を押して認証の開始が成立し、認可先への転送が
    # 返ったことである。焦点が当たっただけでは足りない。
    with_local_oidc_provider do
      visit new_session_path
      mark = log_position

      tab_to(text: I18n.t("sessions.oidc.submit"))
      # button は Space でも Enter でも押せる。ここは Space を送る。
      toggle_focused

      # 端末は局所の発行者の名前を解決できないため、認可先の画面は開かない。
      # 成立したことは、この操作のあとに認可先への転送が返ったことで見る。
      assert redirected_to_authorization?(mark), "認可の開始が成立していない"
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
    user = users(:taro)
    sign_in_as user
    other = user.sessions.create!(user_agent: "別の端末", ip_address: "203.0.113.9")
    visit logins_path
    skip_to_main

    assert_equal 2, user.sessions.count, "別の端末が用意できていない"

    tab_to(text: "この端末以外を終了する")
    press_focused

    assert_text I18n.t("logins.revoked", count: 1)
    assert_not Session.exists?(other.id), "別の端末が残っている"
    assert_equal 1, user.sessions.count, "いま使っている端末まで終わっている"
  end

  test "キーボードだけで自分の設定を保存する" do
    user = users(:taro)
    sign_in_as user
    visit settings_path
    skip_to_main

    assert_nil user.reload.locale, "操作の前から言語が設定されている"

    tab_to(id: "user_locale")
    # 選択欄は矢印で選ぶ。「設定しない」から「日本語」「English」と進む。
    select_next
    select_next
    tab_to(text: "保存する")
    press_focused

    assert_text I18n.t("settings.updated", locale: :en)
    assert_equal "en", user.reload.locale
    # 画面の語句そのものが英語へ変わる。
    assert_text I18n.t("settings.title", locale: :en)
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

    assert_equal 0, exported_count, "押す前に書き出されている"

    tab_to(text: "利用者を書き出す")
    press_focused

    # 書き出しは記録へ残る。応答そのものはファイルであり、画面は変わらない。
    assert_equal 1, exported_count, "書き出しが実行されていない"
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

    assert_not_includes page.current_url, "audit_action=", "操作の前から絞り込まれている"

    tab_to(id: "audit_action")
    # 「すべての操作」から次の種類へ進む。
    select_next
    selected = page.evaluate_script("document.getElementById('audit_action').value").to_s
    tab_to(text: "絞り込む")
    press_focused

    assert_current_path(/audit_action=#{Regexp.escape(selected)}/)
    assert_predicate selected, :present?
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
    # 局所の発行者を立てて、送り出す入口が出る設定にする。
    # 認可の往復そのものは test/controllers/oidc_login_test.rb が確かめる。
    def with_local_oidc_provider(&block)
      @authorize_requests = 0

      with_oidc_provider do |provider|
        original = ENV.slice("AUTHENTICATION_PROVIDER", "OIDC_ISSUER", "OIDC_CLIENT_ID", "OIDC_CLIENT_SECRET")
        ENV["AUTHENTICATION_PROVIDER"] = "oidc"
        ENV["OIDC_ISSUER"] = provider.issuer
        ENV["OIDC_CLIENT_ID"] = "officeweave"
        ENV["OIDC_CLIENT_SECRET"] = "a-client-secret"
        @provider = provider

        # 認可先は局所の発行者である。名前解決と証明書の検証元を渡さないと、
        # 認可の開始そのものが失敗して入口へ戻る。
        Authentication::Oidc.client_factory = lambda do |settings|
          Authentication::Oidc::Client.new(settings).tap do |client|
            client.certificate_store = LocalCertificateTestHelper.trusted.store
            client.resolver = oidc_resolver
          end
        end

        block.call
      ensure
        Authentication::Oidc.client_factory = nil
        %w[AUTHENTICATION_PROVIDER OIDC_ISSUER OIDC_CLIENT_ID OIDC_CLIENT_SECRET].each do |key|
          ENV[key] = original[key]
        end
      end
    end

    # 認可先への転送が返ったか。
    #
    # 記録への書き込みは、端末が要求を終えたあとになることがある。
    # 現れるまで上限つきで待つ。待たないと、書き込みの速さで結果が変わる。
    def redirected_to_authorization?(mark)
      pattern = %r{Redirected to #{Regexp.escape(@provider.issuer)}/authorize}

      Timeout.timeout(LOG_WAIT) do
        sleep(0.1) until pattern.match?(log_since(mark))
        true
      end
    rescue Timeout::Error
      false
    end

    # 記録のいまの位置。ここから後だけを読むことで、他の検査が書いた分と
    # 混ざらないようにする。全体を数えると、並行して走る検査の書き込みで
    # 数が動く。
    def log_position = log_path.size

    def log_since(mark)
      log_path.open("rb") do |file|
        file.seek(mark)
        file.read.to_s.force_encoding(Encoding::UTF_8)
      end
    end

    def log_path = Rails.root.join("log/test.log")

    # 書き出しが実行された回数。書き出しは記録へ残る。
    def exported_count = AuditEvent.with_action("users_exported").count
end
