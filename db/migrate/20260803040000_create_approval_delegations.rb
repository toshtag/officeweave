# 承認の委任を足す。
#
# 承認を担当する利用者が不在のあいだ、別の利用者が代わりに決裁できるように
# する。担当そのものは移さない。移すと、戻し忘れたときに誰が担当なのか
# 分からなくなる。
#
# 決裁の記録へ、誰の代わりに決裁したかを残す列も足す。
class CreateApprovalDelegations < ActiveRecord::Migration[8.1]
  def change
    create_table :approval_delegations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :delegator, null: false, foreign_key: { to_table: :users }
      t.references :delegate, null: false, foreign_key: { to_table: :users }
      t.date :starts_on, null: false
      t.date :ends_on

      t.timestamps
    end

    # 期間で絞る問い合わせが、決裁のたびに走る。
    add_index :approval_delegations, [ :delegate_id, :starts_on ]

    add_reference :request_activities, :on_behalf_of, foreign_key: { to_table: :users }
  end
end
