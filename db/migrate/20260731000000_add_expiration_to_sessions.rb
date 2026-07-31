class AddExpirationToSessions < ActiveRecord::Migration[8.1]
  # 期限の値をここへ直接書く。移行は実行した時点の契約を残すものであり、
  # 後からモデルの定数が変わっても、この移行の結果は変わってはならない。
  ABSOLUTE_TIMEOUT_INTERVAL = "8 hours".freeze

  def up
    add_column :sessions, :last_active_at, :datetime
    add_column :sessions, :expires_at, :datetime

    # 既存のセッションへは、作成時刻を基準にした期限を与える。
    # 移行を実行した時刻から数えると、放置されていたセッションの寿命が
    # 入れ替えのたびに延びる。
    #
    # モデルを参照しない。将来モデルが変わると、この移行が動かなくなる。
    execute <<~SQL.squish
      UPDATE sessions
      SET last_active_at = updated_at,
          expires_at = created_at + INTERVAL '#{ABSOLUTE_TIMEOUT_INTERVAL}'
    SQL

    change_column_null :sessions, :last_active_at, false
    change_column_null :sessions, :expires_at, false

    # 認証のたびに読み、定期削除でも絞り込む。
    add_index :sessions, :last_active_at
    add_index :sessions, :expires_at
  end

  def down
    remove_column :sessions, :expires_at
    remove_column :sessions, :last_active_at
  end
end
