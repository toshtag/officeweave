class AddPeriodCheckToApprovalDelegations < ActiveRecord::Migration[8.1]
  # 終わりの日が始まりより前の委任を、データベース側でも拒む。
  #
  # 重なりを禁じる制約は `daterange(starts_on, ends_on, '[]')` を作る。
  # 前後が逆の値では範囲そのものを作れず、制約に触れる前に「範囲の下端が
  # 上端を超えている」という別の失敗になる。拒む理由としては正しくない。
  #
  # 検査の制約は索引より先に評価されるため、こちらが先に拒む。
  def up
    execute <<~SQL.squish
      UPDATE approval_delegations SET ends_on = starts_on WHERE ends_on < starts_on
    SQL

    execute <<~SQL.squish
      ALTER TABLE approval_delegations
        ADD CONSTRAINT approval_delegations_period_must_not_be_reversed
        CHECK (ends_on IS NULL OR ends_on >= starts_on)
    SQL
  end

  def down
    execute <<~SQL.squish
      ALTER TABLE approval_delegations
        DROP CONSTRAINT approval_delegations_period_must_not_be_reversed
    SQL
  end
end
