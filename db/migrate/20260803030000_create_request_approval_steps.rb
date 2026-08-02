# 申請ごとの承認経路。
#
# 提出の時点の段を写して残す。写さないと、種別の段を後から変えたときに、
# 過去の申請が通った経路が読めなくなる。
#
# 既にある申請へは写さない。写す元は今の段であり、その申請が実際に通った
# 経路とは限らない。経路の記録が無い申請は、種別の段を経路として扱う。
class CreateRequestApprovalSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :request_approval_steps do |t|
      t.references :request, null: false, foreign_key: true
      t.references :approver_department, foreign_key: { to_table: :departments }
      t.references :approver, foreign_key: { to_table: :users }
      t.integer :position, null: false, default: 0
      t.datetime :approved_at

      t.timestamps
    end

    add_index :request_approval_steps, [ :request_id, :position ], unique: true
  end
end
