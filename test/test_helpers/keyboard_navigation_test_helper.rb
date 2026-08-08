# キーボードだけで画面を操作する。
#
# 共通条件 `keyboard` は「主要な操作がキーボードだけで完了する」ことを求める。
# 要素を名前で直接指して押す呼び出し（click_link、click_button、fill_in）は、
# その要素へ到達できることを確かめない。到達できない要素でも通ってしまう。
#
# ここが送るのは Tab、Shift+Tab、Enter、Space、そして文字だけである。
# 焦点の移動はブラウザーに任せ、いま焦点がどこにあるかだけを見る。
module KeyboardNavigationTestHelper
  # Tab を押す回数の上限。
  #
  # 到達できない要素を探し続けて止まらない状態を避ける。画面の操作対象は
  # 数十個であり、これを超えるなら並びそのものを見直す必要がある。
  MAXIMUM_TABS = 120

  # 焦点のある要素まで Tab で進む。
  #
  # 見つからなければ失敗させる。「押せたかどうか」ではなく「到達できたか
  # どうか」を確かめるための補助である。
  def tab_to(text: nil, id: nil, name: nil, backwards: false)
    MAXIMUM_TABS.times do
      press(backwards ? %i[shift tab] : :tab)

      return focused if focused_matches?(text: text, id: id, name: name)
    end

    flunk("キーボードで到達できません（#{[ text, id, name ].compact.join(' ')}）: いまの焦点は #{focused_label}")
  end

  # いま焦点のある要素を押す。
  #
  # リンクとボタンは Enter、チェックボックスと選択欄は Space で操作する。
  # ブラウザーの既定に合わせる。
  # Enter は本来の改行キー（:return）を送る。:enter は数値キーパッド側であり、
  # 押せる要素の既定の動作を起こさないことがある。
  def press_focused = press(:return)

  def toggle_focused = press(:space)

  # 焦点のある選択欄で、次の候補へ移る。
  #
  # 下向きの矢印はブラウザーの既定の操作である。選ばずに送信すると、
  # ブラウザーが「リスト内の項目を選択してください」と止める。
  def select_next = press(:down)

  # いま焦点のある入力欄へ文字を入れる。
  def type(text) = press(text)

  # 読み飛ばしのリンクから本文へ入る。
  #
  # 移動先の並びを毎回たどらずに済む。ここを通らないと、画面ごとに
  # 上部の並びを全部 Tab で越えることになる。
  def skip_to_main
    press(:tab)
    press_focused

    assert_equal "main", focused_id, "読み飛ばしのリンクから本文へ入れません"
  end

  def focused_id = page.evaluate_script("document.activeElement.id").to_s

  def focused_label
    page.evaluate_script(<<~JS).to_s
      (() => {
        const el = document.activeElement;
        if (!el) return "無し";
        return el.tagName.toLowerCase() + " " + (el.id || "") + " " + (el.textContent || "").trim().slice(0, 30);
      })()
    JS
  end

  private
    # 焦点のある要素へ鍵を送る。
    #
    # 要素を名前で探して押すのではなく、いま焦点がある相手へ送る。
    # 到達できていない要素へは、そもそも送れない。
    def press(keys)
      case keys
      when %i[shift tab]
        page.driver.browser.action.key_down(:shift).send_keys(:tab).key_up(:shift).perform
      when :tab
        # 移動そのものは画面全体へ送る。焦点のある要素へ送ると、ファイルを
        # 選ぶ欄では「Tab」という名前のファイルを探しに行く。
        page.driver.browser.action.send_keys(:tab).perform
      else
        page.driver.browser.switch_to.active_element.send_keys(keys)
      end
    end

    def focused
      page.evaluate_script("document.activeElement.outerHTML").to_s
    end

    def focused_matches?(text: nil, id: nil, name: nil)
      page.evaluate_script(<<~JS)
        (() => {
          const el = document.activeElement;
          if (!el || el === document.body) return false;
          // 押せる要素の名前は、本文か value のどちらかにある。
          // 送信ボタンは input であり、本文を持たない。
          const label = ((el.textContent || "") + " " + (el.value || "")).trim();
          const matchesText = #{text.nil? ? "true" : "label.includes(#{text.to_json})"};
          const matchesId = #{id.nil? ? "true" : "el.id === #{id.to_json}"};
          const matchesName = #{name.nil? ? "true" : "el.getAttribute('name') === #{name.to_json}"};
          return matchesText && matchesId && matchesName;
        })()
      JS
    end
end
