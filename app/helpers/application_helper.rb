module ApplicationHelper
  # 画面ごとの見出しと製品名を組み合わせて題名にする。
  # 各画面で題名の組み立て方を書くと、区切り文字や順序がばらつく。
  def page_title
    product_name = t("application.name")
    page_name = content_for(:title)

    page_name.present? ? "#{page_name} - #{product_name}" : product_name
  end

  # 利用者が入力した本文を描画する。
  #
  # 本文の入力欄は書式を持たない複数行のテキストであり、画面にも文書にも、
  # 書式が使えるという説明はない。入力された記号は記号として表示する。
  #
  # simple_format は、既定では入力を HTML として解釈し、許可した種類の
  # タグだけを残す。その許可には a と img が含まれる。そのままでは、
  # 利用者が本文へ任意のリンクと外部の画像を埋め込める。
  #
  # 先にすべてを escape し、simple_format には解釈させない。取り除く形に
  # しないのは、除去すると利用者が入力した文字が黙って消えるためである。
  # 手順書へ HTML の断片を書くことは、この製品では珍しくない。
  #
  # escape には CGI を使う。ActiveSupport の html_escape は、既に安全と
  # 印の付いた値をそのまま返す。渡す側の書き方でこの契約が変わらないよう、
  # 印の有無によらず必ず escape する。
  #
  # 本文を画面へ出す経路はここだけとする。同じ書き方を各画面へ写すと、
  # 本文を表示する画面を足したときに漏れる。実際、直前まで 6 か所が
  # 同じ書き方の写しだった。
  def formatted_body(text, html_options = {})
    simple_format(CGI.escapeHTML(text.to_s), html_options, sanitize: false)
  end

  # 横に並べる入力欄。選択肢そのものが操作の対象になる場合に使う。
  #
  # 補足は包みの外へ置く。包みは横並びであり、内側へ入れると補足が
  # ラベルの隣に来る。縦に並べる入力欄とは位置が違うが、どちらの位置も
  # 書く人ではなくここが決める。
  def inline_field(hint: nil, &block)
    safe_join([ tag.div(capture(&block), class: "#{ApplicationFormBuilder::FIELD_CLASS} form__field--inline"),
                form_hints(hint) ])
  end

  # 入力欄と選択肢の群へ添える補足。
  # 複数渡せる。条件によって出し分ける補足は、nil を混ぜて渡す。
  def form_hints(hint)
    safe_join(Array(hint).compact_blank.map { |text| tag.p(text, class: "form__hint") })
  end
end
