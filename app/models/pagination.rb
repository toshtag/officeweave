# 一覧のページ送り。
#
# 蓄積する一覧は、件数が増えると開けなくなる。1 ページ分だけを読み、
# 前後へ移れるようにする。
#
# 依存を足さない。必要なのは、1 ページ分の読み出しと、前後があるかどうかの
# 判定だけである。ページ番号の並びや無限読み込みは扱わない。
class Pagination
  # 1 ページの件数の上限。
  #
  # 要求で件数を指定できる経路（API）から、際限なく大きな値を渡されても
  # 読む量が決まるようにする。
  MAXIMUM_PER_PAGE = 100

  DEFAULT_PER_PAGE = 25

  attr_reader :per_page

  def initialize(scope, page: nil, per_page: DEFAULT_PER_PAGE)
    @scope = scope
    @per_page = normalized_per_page(per_page)
    @current_page = normalized_page(page)
  end

  def current_page = @current_page

  def records
    @records ||= @scope.offset((@current_page - 1) * @per_page).limit(@per_page).to_a
  end

  # 総数は 1 回だけ数える。ページの組み立てと表示の両方で数えると、
  # 同じ問い合わせが 2 度出る。
  def total_count
    @total_count ||= @scope.count(:all)
  end

  def total_pages = [ (total_count / @per_page.to_f).ceil, 1 ].max

  def next_page? = @current_page < total_pages
  def previous_page? = @current_page > 1

  def next_page = @current_page + 1
  def previous_page = @current_page - 1

  # ページ送りを出すかどうか。1 ページに収まる一覧へは出さない。
  def paginated? = total_pages > 1

  private
    # 読めない値と範囲の外は、最初のページとして扱う。
    #
    # 誤りとして返さない。ページ番号は画面の位置であり、入力の誤りとして
    # 扱っても利用者にできることが増えない。
    def normalized_page(value)
      number = value.to_i

      number.positive? ? number : 1
    end

    def normalized_per_page(value)
      number = value.to_i
      number = DEFAULT_PER_PAGE unless number.positive?

      [ number, MAXIMUM_PER_PAGE ].min
    end
end
