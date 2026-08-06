# 選択欄へ並べる候補。
#
# 選ばせる欄が対象を全件描くと、描く量が組織の規模に比例する。利用者が
# 1000 人いる組織では、予定を 1 件作る画面が 1000 個の入力欄を持つ。
# 読み込む量も、キーボードで送る回数も、そのまま 1000 倍になる。
#
# 上限を置いたうえで、絞り込みで残りへ到達できるようにする。上限だけを
# 置くと、並ばなかった候補を選ぶ手段が無くなる。
#
# 既に選んである候補は必ず含める。含めないと、絞り込んだ状態で保存した
# ときに、画面へ出ていない選択が外れる。
class Candidates
  # 一度に並べる数の上限。
  #
  # 目で追える量に収める。これを超える組織では、絞り込んで選ぶことになる。
  LIMIT = 50

  attr_reader :query

  def initialize(scope, query: nil, selected_ids: [], limit: LIMIT)
    @scope = scope
    @query = query.presence
    @selected_ids = Array(selected_ids).compact_blank.map(&:to_i)
    @limit = limit
  end

  # 並べる候補。選んである分を先に置き、残りを上限まで足す。
  def records
    @records ||= (selected + matched).uniq(&:id)
  end

  # 上限に達したか。画面へ知らせ、これで全部だと読ませない。
  def truncated?
    records.size >= @limit + selected.size && remaining.positive?
  end

  # 並べていない候補の数。絞り込む理由を、数で示す。
  def remaining
    @remaining ||= [ total - records.size, 0 ].max
  end

  def any? = records.any?

  private
    def selected
      @selected ||= @selected_ids.empty? ? [] : @scope.where(id: @selected_ids).to_a
    end

    # 絞り込みは、その模型が持つ検索に委ねる。ここで条件を組み立てると、
    # 検索できる列が模型と選択欄で食い違う。
    def matched
      filtered.where.not(id: @selected_ids).limit(@limit).to_a
    end

    def total
      @total ||= filtered.count(:all)
    end

    def filtered
      @query && @scope.respond_to?(:search) ? @scope.search(@query) : @scope
    end
end
