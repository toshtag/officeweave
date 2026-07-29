class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements do |t|
      t.references :organization, null: false, foreign_key: true
      # 作成者。無効化された利用者の記録も残すため、削除はしない。
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.text :body, null: false
      # 公開範囲。organization は組織全体、departments は指定した部門に限る。
      t.string :visibility, null: false, default: "organization"
      # 公開日時。未設定のものは下書きとして扱う。
      t.datetime :published_at

      t.timestamps
    end

    # 一覧は組織ごとに、公開日時の新しい順で引く。
    add_index :announcements, %i[organization_id published_at]
  end
end
