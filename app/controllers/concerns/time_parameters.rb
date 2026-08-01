# 要求から受け取る日時と日付の解釈。
#
# 解析できない値と、扱える範囲を超える値を同じ扱いにする。両者を分けると、
# 片方だけを見る経路が生まれる。実際、画面側は解析できない値だけを見ており、
# 範囲を超える値がデータベースまで届いて 500 になっていた。
#
# 応答の形はここで決めない。API は 400、画面は一覧への転送であり、
# 同じ誤りでも呼び出す側が期待するものが違う。
module TimeParameters
  extend ActiveSupport::Concern

  # 受け取れない入力。呼び出す側が直せる誤りとして扱う。
  class InvalidParameter < StandardError
    attr_reader :parameter

    def initialize(parameter)
      @parameter = parameter
      super("#{parameter} is not a valid time")
    end
  end

  # 受け取る年の範囲。
  #
  # Ruby は西暦 13 桁の年も解析する。そのまま問い合わせへ渡すと、
  # データベースが扱える範囲を超えて拒み、入力の誤りが 500 になる。
  #
  # 範囲はデータベースの限界そのものではなく、その内側に取る。限界に
  # 合わせると、保存先を変えたときに受け取る値の契約まで動く。
  ACCEPTED_YEARS = (1000..9999)

  private
    def time_param(name)
      parsed_param(name) { |text| Time.zone.parse(text) }
    end

    def date_param(name)
      parsed_param(name) { |text| Date.parse(text) }
    end

    # 未指定は nil を返し、既定値は呼ぶ側が決める。解析できない値は
    # 既定値へ読み替えない。読み替えると、呼び出す側は誤りに気付かない
    # まま、意図と異なる結果を受け取る。
    #
    # 解析できない値は、nil が返る場合と例外になる場合の両方がある。
    # どちらも同じ誤りであるため、同じ扱いにそろえる。
    # Date::Error は ArgumentError の一種であり、別に並べない。
    def parsed_param(name)
      value = params[name]
      return nil if value.blank?

      parsed = begin
        yield value.to_s
      rescue ArgumentError, TypeError
        nil
      end

      raise InvalidParameter, name if parsed.nil? || ACCEPTED_YEARS.exclude?(parsed.year)

      parsed
    end
end
