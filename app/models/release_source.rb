# 検証した木と、公開する木の対応。
#
# 版ごとの評価は commit を 1 つ指す。tag はふつう、その後ろの commit を指す。
# 公開の作業そのもの（変更履歴、版数、検証の記録、機能到達度の更新）が、
# 実測を終えたあとに入るためである。
#
# 同じ commit であることは求めない。求めると、記録を書き足すたびに実測を
# やり直すことになり、実測しない理由になる。
#
# 代わりに、差が記録だけであることを求める。動くもの、組み立てるもの、
# 確かめるものが 1 行でも違えば、公開する木は実測していない木である。
# test も許さない。テストが変わった木は、そのテストを通していない。
class ReleaseSource
  # 実測のあとに変わってよい道。
  #
  # いずれも読み物であり、動作にも組み立てにも入らない。配布する image の
  # 組み立て文脈からも外してある（.dockerignore）。外していないと、読み物を
  # 直しただけで image が変わる。
  #
  # 機能到達度の一覧（docs/product/capability_registry.yml）も、判定の記録を
  # 書き足す先としてここに入る。
  #
  # VERSION は入れない。読み物ではないためである。実行時に読まれ
  # （config/initializers/version.rb）、部品表と書庫の metadata に入り、
  # 配布する image へ焼き込まれる。実測のあとに変えると、測った木と配る木で
  # 版数が違う。版数は実測の前に決める。
  RECORDABLE = [ "CHANGELOG.md", "README.md", "docs/" ].freeze

  attr_reader :tested, :released, :changed_paths

  def initialize(tested:, released:, changed_paths: [])
    @tested = tested.to_s
    @released = released.to_s
    @changed_paths = Array(changed_paths).map(&:to_s).reject(&:empty?)
  end

  # 同じ木か。同じであれば、対応を確かめる必要そのものが無い。
  def same_tree? = tested == released && !tested.empty?

  def valid? = problems.empty?

  # 実測のあとに変わってはならない道のうち、実際に変わったもの。
  def unexpected = changed_paths.reject { |path| recordable?(path) }

  def problems
    return [ "検証した commit が空である" ] if tested.empty?
    return [ "公開する commit が空である" ] if released.empty?
    return [] if same_tree?
    return [] if unexpected.empty?

    [ "実測した木と公開する木で、記録以外が変わっている: #{unexpected.sort.join(', ')}" ]
  end

  def summary
    return "検証した木と公開する木が同じである（#{tested}）" if same_tree?

    "検証 #{tested} から公開 #{released} までの差は記録だけである" \
      "（#{changed_paths.size} 件）"
  end

  private
    def recordable?(path)
      RECORDABLE.any? { |allowed| allowed.end_with?("/") ? path.start_with?(allowed) : path == allowed }
    end
end
