require "browser_test_case"

# 狭い画面での到達性。
#
# 320 CSS px は、達成基準が求める下限である。1280 px の画面を 400% へ拡大した
# 状態も、表示域としてはこれに等しい。どちらも同じ検査で見る。
#
# 見るのは「本文が横へあふれないこと」と「主要な移動先へ届くこと」の 2 つと
# する。横へあふれると、縦に読んでいる途中で本文が左右へ動き、読む位置を
# 見失う。表だけは、その箱の中で横へ動かす。
#
# 表の中身は対象から外す。列の数だけ幅が要るものを縦へ折ると、行と列の
# 対応が読めなくなる。箱に名前と焦点を与え、キーボードでも動かせるようにする。
class NarrowScreenTest < BrowserTestCase
  # 達成基準が求める下限。
  NARROW_WIDTH = 320
  NARROW_HEIGHT = 640

  # 表を持つ画面を必ず含める。列の数だけ幅が要るため、あふれるならここに出る。
  SCREENS = {
    "入口" => "/",
    "お知らせの一覧" => "/announcements",
    "予定の一覧" => "/events",
    "予定の作成" => "/events/new",
    "予約の一覧" => "/reservations",
    "設備・備品の一覧" => "/resources",
    "部門の一覧" => "/departments",
    "文書の一覧" => "/documents",
    "文書の分類の一覧" => "/document_categories",
    "申請の一覧" => "/requests",
    "申請種別の一覧" => "/request_types",
    "利用者の一覧" => "/users",
    "監査記録の一覧" => "/audit_events",
    "ログイン中の端末" => "/logins",
    "外部接続の token" => "/api_tokens",
    "出来事の送信先" => "/webhook_endpoints",
    "承認の委任" => "/approval_delegations",
    "通知の一覧" => "/notifications",
    "利用者と部門の入出力" => "/data_transfers",
    "自分の設定" => "/settings"
  }.freeze

  # 主要な移動先。狭い画面でも、ここから各機能へ入れる必要がある。
  DESTINATIONS = %w[ホーム お知らせ 予定 文書 申請 予約 設備・備品 部門 利用者].freeze

  setup do
    sign_in_as users(:taro)
    resize_to_narrow
  end

  test "狭い画面で本文が横へあふれない" do
    SCREENS.each do |name, path|
      visit path

      assert_operator body_width, :<=, viewport_width + 1,
                      "#{name}（#{path}）が横へあふれる"
    end
  end

  test "狭い画面でも主要な移動先へ届く" do
    visit root_path

    DESTINATIONS.each do |label|
      assert page.has_link?(label, visible: true), "#{label} へ届かない"
    end
  end

  test "表は、その箱の中で横へ動かせる" do
    visit users_path

    box = page.find(".table-scroll", match: :first)

    assert_operator box.evaluate_script("this.scrollWidth"), :>,
                    box.evaluate_script("this.clientWidth"),
                    "表が箱に収まっており、この画面では動かす必要が無い"
  end

  test "表の箱に、焦点と名前がある" do
    # 焦点を当てられない箱は、指で触れる操作だけが動かせる状態になる。
    visit users_path

    box = page.find(".table-scroll", match: :first)

    assert_equal "0", box[:tabindex]
    assert_equal "region", box[:role]
    assert_predicate box[:"aria-label"].to_s, :present?
  end

  test "表の箱へ、キーボードで焦点が届く" do
    # 焦点が届けば、横へ動かす操作はブラウザーが受け持つ。届かない箱は、
    # 指で触れる操作だけが動かせる状態になる。
    visit users_path

    box = page.find(".table-scroll", match: :first)
    box.evaluate_script("this.focus()")

    assert_equal box.native.attribute("outerHTML")[0, 40],
                 page.evaluate_script("document.activeElement.outerHTML")[0, 40],
                 "箱へ焦点が当たらない"
  end

  test "狭い画面でも、キーボードだけで主要な操作を終えられる" do
    visit root_path

    # 読み飛ばしのリンクから本文へ入り、そこから移動する。
    page.send_keys(:tab)
    page.send_keys(:enter)

    assert_equal "main", page.evaluate_script("document.activeElement.id")

    find_link("お知らせ").send_keys(:enter)

    assert_current_path announcements_path
  end

  private
    def resize_to_narrow
      page.driver.browser.manage.window.resize_to(NARROW_WIDTH, NARROW_HEIGHT)
    end

    # 本文の幅で見る。documentElement の値は、内側の箱が持つ動かせる幅まで
    # 含めて報せる版があり、箱に収めた表と区別が付かない。
    def body_width = page.evaluate_script("document.body.scrollWidth")

    def viewport_width = page.evaluate_script("document.documentElement.clientWidth")
end
