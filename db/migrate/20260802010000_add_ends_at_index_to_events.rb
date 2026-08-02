class AddEndsAtIndexToEvents < ActiveRecord::Migration[8.1]
  def change
    # 予定の一覧は、指定日以降に終わる予定へ絞る。
    #
    # 既存の (organization_id, starts_at) はこの条件に使えない。開始時刻の順に
    # 読み進めても、終了時刻の範囲は絞れないためである。planner は表の走査を
    # 選び、終了済みの予定を全件読んでから落としていた。
    #
    # 終了済みの予定に削除の仕組みは無く、走査する量は運用の期間に比例して
    # 増える。組織で等値に絞ってから終了時刻の範囲を見る並びにする。
    add_index :events, [ :organization_id, :ends_at ]
  end
end
