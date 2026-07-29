class AddRoleToUsers < ActiveRecord::Migration[8.1]
  def change
    # 権限は 2 段階だけとする。役割を細かく分けるのは、必要が確認されてからにする。
    add_column :users, :role, :string, null: false, default: "member"
    add_index :users, :role
  end
end
