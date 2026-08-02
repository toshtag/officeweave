require "test_helper"

# ブラウザーへ配信するスクリプトを持たないこと。
#
# JavaScript が動作しない状態でも基本操作が完了することを設計原則としている。
# 配信するものが無いのに配線だけが残ると、依存の更新、脆弱性の監査、
# 全画面の HTML と ETag の契約に、機能を持たない対象が入り続ける。
#
# 配信していないことは、画面の表示や操作の結果からは分からない。
# 出力された HTML そのものを見る。
class ScriptDeliveryTest < ActionDispatch::IntegrationTest
  test "ログインの画面がスクリプトを配信しない" do
    get new_session_url

    assert_select "script", count: 0
  end

  test "認証後の画面がスクリプトを配信しない" do
    sign_in_as users(:taro)

    get root_url

    assert_select "script", count: 0
  end

  # 様式のある画面は、入力の補助のためにスクリプトが入りやすい。
  test "様式のある画面がスクリプトを配信しない" do
    sign_in_as users(:taro)

    get new_announcement_url

    assert_select "script", count: 0
  end

  test "先読みするスクリプトを指示しない" do
    sign_in_as users(:taro)

    get root_url

    assert_select "link[rel=modulepreload]", count: 0
  end

  # 消すのはスクリプトだけである。同じ head にある他の要素は残す。
  test "様式と icon の要素は残る" do
    sign_in_as users(:taro)

    get root_url

    assert_select "link[rel=stylesheet]"
    assert_select "link[rel=icon][type='image/svg+xml']"
    assert_select "link[rel=apple-touch-icon]"
  end

  # CSRF の meta tag は、偽造防止が働いているときだけ出力される。
  # test では既定で無効になっているため、この 1 件だけ有効にして確かめる。
  # 有効にしないと、消してはいけないものが消えても気付けない。
  test "CSRF の meta tag は残る" do
    original = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    sign_in_as users(:taro)

    get root_url

    assert_select "meta[name=csrf-token]"
  ensure
    ActionController::Base.allow_forgery_protection = original
  end

  # 配線を消しても、実体が残っていれば次に誰かが繋ぎ直せてしまう。
  test "配信するスクリプトの置き場所を持たない" do
    assert_not Rails.root.join("app/javascript").exist?,
               "app/javascript が残っている"
    assert_not Rails.root.join("config/importmap.rb").exist?,
               "config/importmap.rb が残っている"
  end
end
