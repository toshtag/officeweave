class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.references :organization, null: false, foreign_key: true
      # 予定の持ち主。編集できるのは持ち主と管理者に限る。
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :description
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      # 終日の予定。時刻を持たないものとして表示する。
      t.boolean :all_day, null: false, default: false
      # 公開範囲。private は持ち主だけ、organization は組織全体、
      # departments は指定した部門に限る。
      t.string :visibility, null: false, default: "organization"

      t.timestamps
    end

    # 期間の重なりで引くため、開始時刻に索引を置く。
    add_index :events, %i[organization_id starts_at]
  end
end
