# 運用者へ知らせる異常。
#
# 判断の元は運用診断とする。同じことを 2 か所で判定すると、片方だけが
# 変わったときに、診断では出るのに通知では出ない状態になる。
#
# 知らせるのは、失敗と、知らせる印の付いた注意だけとする。設定として
# 選んだ結果の注意（内部宛先の許可など）を毎日送ると、通知そのものが
# 読まれなくなる。
class OperationalReport
  def initialize(checks: nil)
    @checks = checks || Diagnostics.new.run
  end

  def issues
    @issues ||= @checks.select { |check| check[:notify] }
  end

  def any? = issues.any?

  # 何が起きているかを表す値。
  #
  # 異常の名前と状態の組から作る。同じ異常が続いているあいだは同じ値になり、
  # 直った・別の異常が増えたときだけ変わる。詳細の文面は入れない。文面には
  # 件数や時刻が入り、内容が変わっていなくても毎回違う値になる。
  #
  # 長さに上限を置く。異常が同時に多数出た場合でも、値として保存できる
  # 大きさに収める。切り詰めた場合も、切り詰める前の要約から作った値が
  # 先頭に残るため、別の組み合わせと同じにはならない。
  def occurrence
    names = issues.map { |issue| "#{issue[:name]}:#{issue[:status]}" }.sort.join(",")

    Digest::SHA256.hexdigest(names)
  end
end
