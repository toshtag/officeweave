# 入力欄 1 つ分の組み立て。
#
# ラベル、入力、補足の並びと class 名を、ここだけが決める。
# 各画面へ書き写す形にすると、写し先が増えるにつれて基準がばらつく。実際、
# 22 のテンプレートへ同じ 4 行が写されており、補足の位置は 2 通りに分かれていた。
#
# 生成する HTML は写していたときと同じにする。class 名の設計そのものは
# ここでは扱わない。
class ApplicationFormBuilder < ActionView::Helpers::FormBuilder
  FIELD_CLASS = "form__field".freeze
  LABEL_CLASS = "form__label".freeze
  INPUT_CLASS = "form__input".freeze

  # 縦に並べる入力欄。
  #
  #   form.field :name, :text_field, required: true
  #   form.field :capacity, :number_field, min: 1, hint: t("resources.form.capacity_hint")
  #
  # 入力そのものを組み立てられない場合は block を渡す。申請の種別のように、
  # 保存済みでは入力ではなく値を表示する欄がある。
  #
  #   form.field :request_type_id do
  #     ...
  #   end
  #
  # html の指定は positional な hash として渡す。collection_select や select は
  # 選択肢の options を先に取るため、keyword のまま渡すと受け取る位置が変わる。
  #
  # id を明示した場合は、ラベルの結び付け先も同じ id にする。同じ画面へ
  # 同じ名前の入力欄を 2 つ置く場合に必要になる。結び付けが崩れると、
  # ラベルから入力欄へ移れない。
  def field(name, type = nil, *arguments, label: nil, hint: nil, **options, &block)
    contents = if block
      @template.capture(&block)
    else
      public_send(type, name, *arguments, options.merge(class: INPUT_CLASS))
    end

    label_options = { class: LABEL_CLASS }
    label_options[:for] = options[:id] if options.key?(:id)

    @template.form_field(hint: hint) do
      @template.safe_join([ label(name, label, **label_options), contents ])
    end
  end
end
