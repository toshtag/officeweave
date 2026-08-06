# 委任を受けて、どこまで承認を担当できるか。
#
# 委任は担当を移さない。決裁できる範囲を広げるだけである。その範囲は、決裁の
# 立場、承認待ちの一覧、申請の参照、通知の対象の 4 か所で使う。別々に組み立てて
# いたため、模型では代理で決裁できるのに画面からは申請を開けない、管理者の段を
# 委ねても一覧に出ない、といった食い違いが起きていた。
#
# 範囲の解き方はここへ 1 つだけ置く。条件を分けて持つと、片方だけが変わる。
class DelegatedApproval
  class << self
    # 委任を受けて担当できる部門。
    def department_ids(user)
      Membership.where(user_id: ApprovalDelegation.delegators_for(user)).select(:department_id)
    end

    # 部門を指定しない段（管理者が担当する段）を、委任を受けて担当できるか。
    def administrator?(user)
      User.active.exists?(id: ApprovalDelegation.delegators_for(user), role: "administrator")
    end

    # その担当者たちから委任を受けている利用者。
    #
    # 受け取る側も利用できることを条件にする。委任した側の条件は、
    # 渡される担当者の絞り込みが持つ。
    def delegates_of(approvers)
      User.active.where(id: ApprovalDelegation.active.where(delegator_id: approvers.select(:id))
                                                     .select(:delegate_id))
    end
  end
end
