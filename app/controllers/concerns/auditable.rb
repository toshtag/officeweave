# 重要な操作を記録へ残す。
#
# 記録する場所を controller に限る。
# 模型側で自動的に残すと、取り込みや初期データの投入まで記録され、
# 誰の操作なのかが分からない記録が混ざる。
#
# 状態を変える入口は、記録するか・しないかを必ず宣言する。宣言が無い入口は
# 検査（test/configuration/audit_assignment_test.rb）で落とす。宣言を義務に
# しないと、記録の無い入口と、記録すべきなのに書き忘れた入口を区別できない。
module Auditable
  extend ActiveSupport::Concern

  class_methods do
    # 記録する入口。どの記録を残すかは、その動作の中で決める。
    # 制御部から直接呼ばない場合（RequestDecision など）も、入口はここが持つ。
    def records_audit(*actions)
      audit_assignment[:recorded] |= actions.map(&:to_s)
    end

    # 記録しない入口。理由を必ず書く。
    #
    # 理由の無い「記録しない」は、判断した結果と、考えていないことの区別が
    # 付かない。書かせることで、次に読む人が判断をやり直せる。
    def records_no_audit(*actions, reason:)
      raise ArgumentError, "記録しない理由を書く" if reason.to_s.strip.empty?

      actions.each { |action| audit_assignment[:not_recorded][action.to_s] = reason }
    end

    def audit_assignment
      @audit_assignment ||= { recorded: [], not_recorded: {} }
    end

    # その動作の割り当て。記録するなら :recorded、記録しないなら理由の文字列、
    # 宣言が無ければ nil を返す。
    #
    # 上位の制御部から引き継がない。入口を持つ制御部が、自分で宣言する。
    def audit_assignment_for(action)
      action = action.to_s

      return :recorded if audit_assignment[:recorded].include?(action)

      audit_assignment[:not_recorded][action]
    end
  end

  private
    def record_audit_event(action, target: nil, details: {}, organization: nil, actor: :current)
      AuditEvent.record(
        organization: organization || current_organization,
        actor: actor == :current ? Current.user : actor,
        action: action,
        target: target,
        details: details,
        ip_address: request.remote_ip
      )
    end
end
