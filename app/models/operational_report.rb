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
end
