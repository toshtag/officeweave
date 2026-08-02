class AddEndsAtIndexToReservations < ActiveRecord::Migration[8.1]
  def change
    # 予約の一覧は、指定日以降に終わる予約へ絞る。
    #
    # 既存の索引はどれもこの条件に使えない。organization_id 単独では組織で
    # 絞れるだけであり、(resource_id, starts_at) は重なりの判定のためのもので、
    # 一覧の条件には設備の指定が入らない。planner は表の走査を選び、
    # 終了済みの予約を全件読んでから落としていた。
    #
    # 終了済みの予約に削除の仕組みは無く、走査する量は運用の期間に比例して
    # 増える。組織で等値に絞ってから終了時刻の範囲を見る並びにする。
    add_index :reservations, [ :organization_id, :ends_at ]
  end
end
