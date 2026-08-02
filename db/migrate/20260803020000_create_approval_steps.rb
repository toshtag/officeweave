# 承認の段を、種別ごとの並びとして持つ。
#
# 既にあった request_types.approver_department_id を 1 段目として移す。
# 進行中の申請の意味を変えないため、すべての種別へ 1 段を作る。
# 承認部門が未指定だった種別は、部門を指定しない段（管理者が担当）になる。
#
# 移し終えてから列を落とす。両方を残すと、担当の正本が 2 か所になる。
class CreateApprovalSteps < ActiveRecord::Migration[8.1]
  def up
    create_table :approval_steps do |t|
      t.references :request_type, null: false, foreign_key: true
      t.references :approver_department, foreign_key: { to_table: :departments }
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    # 同じ並びの段を 2 つ持てないようにする。どちらが先かを決められない。
    add_index :approval_steps, [ :request_type_id, :position ], unique: true

    # 申請が待っている段。並びの値で指す。
    #
    # 既にある申請は 1 段目を待っている状態とする。移した段の並びと同じ値を
    # 既定にすることで、進行中の申請の担当が変わらない。
    add_column :requests, :current_step_position, :integer, null: false, default: 10

    # どの段の決裁かを記録へ残す。過去の記録は単段であり、1 段目とする。
    add_column :request_activities, :step_position, :integer

    execute(<<~SQL)
      INSERT INTO approval_steps (request_type_id, approver_department_id, position, created_at, updated_at)
      SELECT id, approver_department_id, 10, NOW(), NOW() FROM request_types
    SQL

    remove_reference :request_types, :approver_department, foreign_key: { to_table: :departments }
  end

  def down
    add_reference :request_types, :approver_department, foreign_key: { to_table: :departments }

    execute(<<~SQL)
      UPDATE request_types SET approver_department_id = (
        SELECT approver_department_id FROM approval_steps
        WHERE approval_steps.request_type_id = request_types.id
        ORDER BY position LIMIT 1
      )
    SQL

    remove_column :request_activities, :step_position
    remove_column :requests, :current_step_position
    drop_table :approval_steps
  end
end
