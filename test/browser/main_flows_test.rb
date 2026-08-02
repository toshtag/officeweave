require "browser_test_case"

# 主要な流れを実ブラウザーで通す。
#
# 業務としての正しさは rack_test の層で確かめている。ここで確かめたいのは、
# 実際のブラウザーで操作が成立するかである。押せない位置に重なった操作、
# CSS の指定で見えていない操作、ブラウザーが解釈しない入力欄の指定は、
# HTML を解析するだけの実行方法では通ってしまう。
class MainFlowsTest < BrowserTestCase
  test "ログインし、入口を見て、ログアウトする" do
    sign_in_as users(:taro)

    assert_selector "h1", text: I18n.t("home.heading")
    assert_text I18n.t("home.greeting", name: users(:taro).name)

    sign_out

    assert_selector "h1", text: I18n.t("sessions.new.heading")
  end

  # 日時の入力欄は、ブラウザーが独自の見せ方で解釈する。
  # HTML を解析するだけでは、実際に値を入れられるか分からない。
  test "予定を作る" do
    sign_in_as users(:taro)

    visit events_path
    click_link I18n.t("events.index.new")

    fill_in Event.human_attribute_name(:title), with: "設備の点検"
    fill_in Event.human_attribute_name(:starts_at),
            with: 1.day.from_now.change(hour: 9).strftime("%Y-%m-%dT%H:%M")
    fill_in Event.human_attribute_name(:ends_at),
            with: 1.day.from_now.change(hour: 10).strftime("%Y-%m-%dT%H:%M")
    choose I18n.t("events.visibilities.private")
    click_button I18n.t("helpers.submit.create")

    assert_text I18n.t("events.created")
    assert_text "設備の点検"
  end

  # 申請は複数の画面と利用者をまたぐ。移動のたびに操作が押せる位置に
  # あることを確かめる。
  test "申請を出し、別の利用者が承認する" do
    # 表示する言語が利用者ごとに異なると、確かめる文言が場面で変わる。
    # 日本語で表示される利用者だけを使う。
    sign_in_as users(:approver)

    visit new_request_path
    select request_types(:expense).name, from: Request.human_attribute_name(:request_type)
    fill_in Request.human_attribute_name(:title), with: "棚卸し用品の購入"
    click_button I18n.t("helpers.submit.create")

    assert_text I18n.t("requests.created")

    click_button I18n.t("requests.submit")

    assert_text I18n.t("requests.statuses.pending")

    sign_out
    sign_in_as users(:taro)

    visit requests_path
    click_link "棚卸し用品の購入"
    fill_in I18n.t("request_decisions.comment"), with: "確認しました。"
    click_button I18n.t("request_decisions.approve")

    assert_text I18n.t("request_decisions.approved")
  end

  # 絞り込みは選択欄と送信の組み合わせで動く。
  test "一覧を絞り込む" do
    sign_in_as users(:taro)

    visit users_path
    fill_in I18n.t("users.index.query"), with: users(:approver).name
    click_button I18n.t("events.index.filter")

    assert_text users(:approver).email_address
    assert_no_text users(:taro).email_address
  end

  # 言語の切り替えは、押せる位置にある操作でなければ使えない。
  test "表示する言語を切り替える" do
    sign_in_as users(:taro)

    # 押すのは実際に見えている文字である。説明のための aria-label ではなく、
    # 利用者が読む表記で選ぶ。
    click_button I18n.t("locale_switcher.names.en")

    assert_selector "html[lang='en']", visible: :all
    assert_selector "h1", text: I18n.t("home.heading", locale: :en)
  end
end
