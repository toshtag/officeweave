# 版として本番準備済みと判定してよいか。
#
# 判定を「そう書いた」だけで成立させない。Core と横断の品質が揃っていない
# 版を本番準備済みと呼べてしまえば、この一覧は完成の判断に使えない。
#
# 規則をここへ 1 つだけ置く。検査の側に書くと、評価が 1 件も無い時期に
# 何も確かめないまま通る。
class ReleaseReadiness
  def initialize(registry)
    @registry = registry
  end

  # 揃っているか。書いてよいかどうかの判断はこれだけで決まる。
  def allows_passed? = incomplete.empty?

  def valid? = problems.empty?

  def problems
    @problems ||= passed.any? && !allows_passed? ? [ incomplete_message ] : []
  end

  private
    def passed
      @registry.fetch("release_gates").flat_map { |gate| gate.fetch("evaluations") }
               .select { |evaluation| evaluation["result"] == "passed" }
    end

    def incomplete
      core = @registry.fetch("capabilities").select { |c| c["stage"] == "core" }
      gates = @registry.fetch("cross_cutting_gates")

      (core + gates).reject { |entry| entry["state"] == "complete" }
    end

    def incomplete_message
      "complete でない機能または横断の品質がある: #{incomplete.map { |e| e['id'] }.join(', ')}"
    end
end
