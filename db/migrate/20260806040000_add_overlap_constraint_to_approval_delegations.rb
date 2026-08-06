class AddOverlapConstraintToApprovalDelegations < ActiveRecord::Migration[8.1]
  # 期間の重なりを、データベース側でも拒む。
  #
  # 模型側の確認だけでは、同時に申し込まれた場合に両方が通る。確かめてから
  # INSERT するまでの間に、相手も同じ確認を終えている。
  #
  # 既にある記録に重なりがあると、制約を足せない。重なりは「できることは
  # 同じで、読む量だけが増える」状態であるため、重なる区間をひとつへ
  # まとめてから足す。まとめても、その委任で決裁できる日は 1 日も変わらない。
  #
  # 期間は日の単位で、終わりの日を含む。模型の判定（`ends_on >= on`）と
  # そろえるため、範囲は `[]` とする。
  def up
    merge_overlapping_periods

    execute <<~SQL.squish
      ALTER TABLE approval_delegations
        ADD CONSTRAINT approval_delegations_must_not_overlap
        EXCLUDE USING gist (
          delegator_id WITH =,
          delegate_id WITH =,
          daterange(starts_on, ends_on, '[]') WITH &&
        )
    SQL
  end

  def down
    execute <<~SQL.squish
      ALTER TABLE approval_delegations
        DROP CONSTRAINT approval_delegations_must_not_overlap
    SQL
  end

  private
    # 同じ組で重なる区間を、その和へまとめる。
    #
    # 並べて、直前までの終わりより後から始まる行を新しい組の先頭とする。
    # 終わりを決めない委任は無限として扱う。組の代表は最も古い行とし、
    # 残りは消す。決裁できる日の集合は変わらない。
    def merge_overlapping_periods
      execute <<~SQL
        WITH ordered AS (
          SELECT id, delegator_id, delegate_id, starts_on, ends_on,
                 MAX(COALESCE(ends_on, 'infinity'::date)) OVER (
                   PARTITION BY delegator_id, delegate_id
                   ORDER BY starts_on, id
                   ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                 ) AS preceding_end
            FROM approval_delegations
        ), marked AS (
          SELECT *,
                 CASE WHEN preceding_end IS NULL OR starts_on > preceding_end THEN 1 ELSE 0 END AS starts_group
            FROM ordered
        ), grouped AS (
          SELECT *,
                 SUM(starts_group) OVER (
                   PARTITION BY delegator_id, delegate_id ORDER BY starts_on, id
                 ) AS group_number
            FROM marked
        ), merged AS (
          SELECT MIN(id) AS keep_id,
                 MIN(starts_on) AS merged_starts_on,
                 CASE WHEN BOOL_OR(ends_on IS NULL) THEN NULL ELSE MAX(ends_on) END AS merged_ends_on,
                 ARRAY_AGG(id) AS member_ids
            FROM grouped
           GROUP BY delegator_id, delegate_id, group_number
          HAVING COUNT(*) > 1
        )
        UPDATE approval_delegations
           SET starts_on = merged.merged_starts_on,
               ends_on = merged.merged_ends_on,
               updated_at = NOW()
          FROM merged
         WHERE approval_delegations.id = merged.keep_id
      SQL

      execute <<~SQL
        WITH ordered AS (
          SELECT id, delegator_id, delegate_id, starts_on, ends_on,
                 MAX(COALESCE(ends_on, 'infinity'::date)) OVER (
                   PARTITION BY delegator_id, delegate_id
                   ORDER BY starts_on, id
                   ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
                 ) AS preceding_end
            FROM approval_delegations
        ), marked AS (
          SELECT *,
                 CASE WHEN preceding_end IS NULL OR starts_on > preceding_end THEN 1 ELSE 0 END AS starts_group
            FROM ordered
        ), grouped AS (
          SELECT *,
                 SUM(starts_group) OVER (
                   PARTITION BY delegator_id, delegate_id ORDER BY starts_on, id
                 ) AS group_number
            FROM marked
        )
        DELETE FROM approval_delegations
         WHERE id IN (
           SELECT id FROM grouped g
            WHERE g.id <> (
              SELECT MIN(id) FROM grouped h
               WHERE h.delegator_id = g.delegator_id
                 AND h.delegate_id = g.delegate_id
                 AND h.group_number = g.group_number
            )
         )
      SQL
    end
end
