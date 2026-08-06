# 一覧が読み込む期間。
#
# 時間の並びで見る一覧には、ページ送りではなく期間を持たせる。予定や予約は
# 「次の何件」ではなく「いつからいつまで」で見るためであり、番号で区切ると
# 同じ日の記録が 2 ページに分かれる。
#
# 上限を必ず持たせる。始まりだけを受け取る形では、蓄積した記録がそのまま
# 読み込む量になる。1 年先まで積んだ組織では、その全部が 1 回の要求で返る。
#
# 期間の長さにも上限を置く。利用者が終わりを遠くへ指定すれば同じことが起き、
# 上限を持たせた意味が無くなる。
class DateWindow
  # 終わりを指定しなかった場合に見る日数。
  #
  # 1 か月ぶんとする。予定と予約は、その月のうちに何があるかを見るために
  # 開かれる。短くすると、開くたびに終わりを指定し直すことになる。
  DEFAULT_DAYS = 31

  # 指定できる期間の長さの上限。
  #
  # 1 年とする。年度をまたいで見たい場合に足りる長さであり、これを超える
  # 範囲は、画面ではなく書き出しで扱うべき量になる。
  MAXIMUM_DAYS = 366

  attr_reader :from, :to

  def initialize(from: nil, to: nil, today: Date.current)
    @from = from || today
    @to = bounded(to)
  end

  # 指定が上限を超えていたか。画面へ知らせ、切り詰めたことを黙って隠さない。
  def truncated? = @truncated

  # 終わりの日を含む。日付で指定する期間であり、その日の分は入る。
  def covers = @from..@to

  private
    def bounded(value)
      limit = @from + MAXIMUM_DAYS

      if value.nil?
        @truncated = false
        return @from + DEFAULT_DAYS
      end

      # 始まりより前の終わりは、その日 1 日として扱う。誤りとして拒むと、
      # 日付を入れ替えている途中の操作が失敗する。
      value = @from if value < @from

      @truncated = value > limit
      @truncated ? limit : value
    end
end
