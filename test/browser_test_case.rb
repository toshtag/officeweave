require "test_helper"
require "capybara/selenium/driver"

# 実ブラウザーでの検証。
#
# 既定のシステムテストは rack_test で実行する（application_system_test_case.rb）。
# こちらは、実際のブラウザーが読める HTML を返しているかを確かめる層である。
# rack_test は HTML を解析するだけで、要素が重なって押せない、CSS の指定で
# 見えない、といった状態を検知しない。
#
# ブラウザーは別のコンテナで動かす。開発用のイメージへ入れると、イメージの
# 大きさと組み立て時間が増え、検証の実行環境も利用者の環境から離れる。
#
#   docker compose -f compose.yaml -f compose.browser.yaml up -d
#   docker compose -f compose.yaml -f compose.browser.yaml exec web bin/rails test:browser
#
# 接続先が無い状態では実行できない。黙って通過させると、検証したつもりで
# 何も確かめていない状態になる。
# 移動の境目で掴み直す。
#
# 送信を押すと画面が入れ替わる。その途中で要素を掴むと、Chrome は
# 「別の文書のものだ」として拒む。
#
#   Node with given id does not belong to the document
#
# Capybara は掴み直す仕組みを持つが、この報せ方を知らないため 1 度で失敗する。
# 掴み直しの対象へ加える。実際に、絞り込みの送信の直後で 8 回に 1 回失敗した。
#
# 掴み直しても直らない不具合は、待つ時間を使い切ったあとに同じ内容で報される。
# 見逃す形にはしない。
module RetryWhenDocumentReplaced
  def invalid_element_errors
    super + [ Selenium::WebDriver::Error::UnknownError ]
  end
end

Capybara::Selenium::Driver.prepend(RetryWhenDocumentReplaced)

class BrowserTestCase < ActionDispatch::SystemTestCase
  REMOTE_URL = ENV["SELENIUM_REMOTE_URL"]

  # ブラウザーから見たテスト用サーバーの宛先。ブラウザーは別のコンテナで
  # 動くため、localhost では届かない。
  APPLICATION_HOST = ENV.fetch("BROWSER_TEST_APPLICATION_HOST", "web").freeze

  # 待ち受ける口を固定する。ブラウザーへ渡す宛先を、起動後に決まる値へ
  # 合わせられない。
  SERVER_PORT = 3400

  # 要素が現れるまで待つ上限。既定の 2 秒は、同じプロセスで解析する実行方法に
  # 合わせた値である。別のコンテナのブラウザーへ指示し、その要求がこちらの
  # サーバーへ戻ってくる経路では足りず、画面の読み込み中に探し始めて失敗する。
  MAXIMUM_WAIT = 10

  # 表示する言語は日本語へ固定する。ブラウザーが送る Accept-Language は
  # 実行環境で決まり、既定では英語になる。他のテストと違う言語で動くと、
  # 同じ画面を確かめているつもりで別の文言を見ることになる。
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ],
            options: { browser: :remote, url: REMOTE_URL } do |options|
    options.add_argument("--lang=ja")
    options.add_preference("intl.accept_languages", "ja")
  end

  setup do
    # 別のコンテナから届くようにする。既定の localhost では、
    # ブラウザーからテスト用サーバーへ到達できない。
    Capybara.server_host = "0.0.0.0"
    Capybara.server_port = SERVER_PORT
    Capybara.app_host = "http://#{APPLICATION_HOST}:#{SERVER_PORT}"

    Capybara.default_max_wait_time = MAXIMUM_WAIT
  end

  # 画面と同じ経路でログインする。
  # 内部の仕組みを直接呼ぶと、ログイン画面そのものの退行を検知できない。
  def sign_in_as(user, password: "password-for-tests")
    visit new_session_path
    fill_in "email_address", with: user.email_address
    fill_in "password", with: password
    click_button I18n.t("sessions.new.submit")

    # 完了を待つ。押した直後は移動の途中であり、続けて別の画面へ移ろうとすると
    # その指示が捨てられ、元の画面に留まったまま次の操作を探すことになる。
    assert_text I18n.t("sessions.signed_in")
  end

  def sign_out
    click_button I18n.t("sessions.sign_out")

    assert_text I18n.t("sessions.signed_out")
  end
end
