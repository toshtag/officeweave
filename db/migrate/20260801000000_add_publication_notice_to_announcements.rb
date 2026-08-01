class AddPublicationNoticeToAnnouncements < ActiveRecord::Migration[8.1]
  def up
    add_column :announcements, :notified_at, :datetime

    # 既に公開されているお知らせは、作成または更新の時点で知らせ済みである。
    # 空のままにすると、この移行の直後に過去のお知らせがすべて再送される。
    #
    # モデルを参照しない。将来モデルが変わると、この移行が動かなくなる。
    execute <<~SQL.squish
      UPDATE announcements
      SET notified_at = published_at
      WHERE published_at IS NOT NULL AND published_at <= CURRENT_TIMESTAMP
    SQL

    # 定期実行が毎回絞り込む。公開待ちと知らせ済みを外した残りだけを見る。
    add_index :announcements, [ :published_at, :notified_at ]
  end

  def down
    remove_column :announcements, :notified_at
  end
end
