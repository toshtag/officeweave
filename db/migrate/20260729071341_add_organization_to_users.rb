class AddOrganizationToUsers < ActiveRecord::Migration[8.1]
  def change
    # 既存の利用者がいる環境では、先に既定の組織へ割り当ててから制約を付ける。
    add_reference :users, :organization, foreign_key: true

    reversible do |direction|
      direction.up do
        organization_id = execute(<<~SQL).first&.fetch("id")
          INSERT INTO organizations (name, code, created_at, updated_at)
          VALUES ('OfficeWeave', 'default', NOW(), NOW())
          ON CONFLICT (code) DO UPDATE SET updated_at = NOW()
          RETURNING id
        SQL

        execute("UPDATE users SET organization_id = #{organization_id.to_i} WHERE organization_id IS NULL")
      end
    end

    change_column_null :users, :organization_id, false
  end
end
