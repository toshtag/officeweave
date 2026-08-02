require "test_helper"

# 入力欄の組み立ての契約を固定する。
#
# 崩れ方は、画面を足すときに写しが戻る形で入る。組み立ての結果だけでなく、
# 包みの記述が画面へ現れていないことも確かめる。
class ApplicationFormBuilderTest < ActionView::TestCase
  # 補助は ApplicationHelper に置く。組み立てはその上で成り立つ。
  tests ApplicationHelper

  # 包みの直接の記述。ここが増えると、class 名を変える先が再び散る。
  # form__fieldset は選択肢の群を囲むもので、入力欄の包みとは別物である。
  FIELD_MARKUP = /class="form__field["\s]/

  setup do
    @resource = Resource.new(name: "会議室")
    @form = ApplicationFormBuilder.new(:resource, @resource, self, {})
  end

  test "包み、ラベル、入力の順に組み立てる" do
    assert_equal %(<div class="form__field">) +
                 %(<label class="form__label" for="resource_name">名称</label>) +
                 %(<input class="form__input" type="text" value="会議室" name="resource[name]" id="resource_name" />) +
                 %(</div>),
                 @form.field(:name, :text_field)
  end

  test "html の指定を入力へ渡す" do
    assert_includes @form.field(:name, :text_field, required: true), %(required="required")
  end

  # 選択肢を取る入力は、options を positional に受け取る。
  # keyword のまま渡すと、選択肢の options が html の指定として扱われる。
  test "選択肢の options と html の指定を取り違えない" do
    result = @form.field(:name, :select, %w[a b], { include_blank: true }, required: true)

    assert_includes result, %(<option value="" label=" "></option>)
    assert_includes result, %(required="required")
  end

  test "ラベルの文言を指定できる" do
    assert_includes @form.field(:name, :text_field, label: "呼び名"), ">呼び名</label>"
  end

  test "補足を包みの内側へ置く" do
    result = @form.field(:name, :text_field, hint: "60 文字まで")

    assert_includes result, %(<p class="form__hint">60 文字まで</p></div>)
  end

  test "補足を複数置ける" do
    result = @form.field(:name, :text_field, hint: [ "ひとつ目", "ふたつ目" ])

    assert_includes result, %(<p class="form__hint">ひとつ目</p><p class="form__hint">ふたつ目</p>)
  end

  # 条件で出し分ける補足は nil のまま渡す。呼ぶ側で分岐を書かせない。
  test "空の補足は置かない" do
    result = @form.field(:name, :text_field, hint: [ "ひとつ目", nil, "" ])

    assert_equal 1, result.scan("form__hint").size
  end

  test "入力を組み立てられない場合は block を受け取る" do
    result = @form.field(:name) { tag.p("会議室") }

    assert_includes result, %(<label class="form__label" for="resource_name">名称</label><p>会議室</p>)
  end

  # 横並びの包みは flex-direction: row である。補足を内側へ入れると
  # ラベルの隣に来るため、外側へ置く。
  test "横に並べる入力欄では、補足を包みの外側へ置く" do
    result = inline_field(hint: "予約を受け付けない設備にできます") { tag.input }

    assert_includes result, %(</div><p class="form__hint">予約を受け付けない設備にできます</p>)
  end

  test "横に並べる入力欄の包みを組み立てる" do
    assert_equal %(<div class="form__field form__field--inline"><input></div>), inline_field { tag.input }
  end

  test "画面へ包みを直接書かない" do
    offenders = Dir.glob(Rails.root.join("app/views/**/*.erb")).flat_map do |path|
      relative = Pathname.new(path).relative_path_from(Rails.root)

      File.read(path).lines.each_with_index.filter_map do |line, index|
        "#{relative}:#{index + 1}" if line.match?(FIELD_MARKUP)
      end
    end

    assert_empty offenders
  end
end
