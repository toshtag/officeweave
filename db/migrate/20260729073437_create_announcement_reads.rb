class CreateAnnouncementReads < ActiveRecord::Migration[8.1]
  def change
    create_table :announcement_reads do |t|
      t.references :announcement, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :read_at, null: false

      t.timestamps
    end

    # 同じ利用者の既読を二重に記録しない。
    add_index :announcement_reads, %i[announcement_id user_id], unique: true,
              name: "index_announcement_reads_on_pair"
  end
end
