class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :department, null: false, foreign_key: true
      # 主たる所属。連絡先の表示や既定の絞り込みに使う。
      t.boolean :primary, null: false, default: false

      t.timestamps
    end

    # 同じ部門へ二重に所属させない。
    add_index :memberships, %i[user_id department_id], unique: true

    # 主たる所属は利用者ごとに 1 件までとする。
    add_index :memberships, :user_id, unique: true, where: "\"primary\"", name: "index_memberships_on_primary_user"
  end
end
