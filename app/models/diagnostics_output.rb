# 診断の結果を、コマンドの出力へ組み立てる。
#
# 組み立てを task から切り離す。task の中に置くと、出力の形と終了状態を
# 確かめるために毎回コマンドを起動することになり、確かめる範囲も
# 「動いた・動かない」までしか届かない。
#
# 運用者はこの出力を読み、記録として残す。自動実行は終了状態だけを見る。
# どちらも契約であり、変えるときは呼ぶ側の手順も変わる。
class DiagnosticsOutput
  # 状態ごとの印。桁をそろえ、並べたときに読み取れるようにする。
  MARKS = { ok: "OK  ", warning: "注意", error: "失敗" }.freeze

  def initialize(checks)
    @checks = checks
  end

  def lines
    @checks.flat_map { |check| lines_for(check) } + [ "", summary ]
  end

  def summary
    "確認 #{@checks.size} 件、注意 #{count(:warning)} 件、失敗 #{count(:error)} 件"
  end

  # 失敗がある状態で 0 を返すと、自動実行で見落とす。
  #
  # 注意では 0 以外にしない。設定として選んだ結果の注意で止めると、
  # 注意そのものが読まれなくなる。
  def failed? = count(:error).positive?

  private
    def lines_for(check)
      line = "#{MARKS.fetch(check[:status])}  #{check[:name]}"

      check[:detail].present? ? [ line, "      #{check[:detail]}" ] : [ line ]
    end

    def count(status) = @checks.count { |check| check[:status] == status }
end
