require "test_helper"

# 予約の一覧が使う索引。
#
# 一覧は指定日以降に終わる予約へ絞る。終了済みの予約は消えないため、
# その条件に合う索引が無いと、走査する量が運用の期間に比例して増える。
class ReservationListingIndexTest < ActiveSupport::TestCase
  ENDS_AT_INDEX = "index_reservations_on_organization_id_and_ends_at".freeze

  # 索引の有無で確かめる。実行の速さで確かめると、実行環境の速さと、
  # そのときのデータ量で planner の選択が変わり、間欠的に失敗する。
  test "終了時刻の絞り込みのための索引がある" do
    index = indexes.find { |candidate| candidate.name == ENDS_AT_INDEX }

    assert_not_nil index, "終了時刻で絞り込める索引が無い"
    assert_equal %w[organization_id ends_at], index.columns
  end

  # 索引の並びと絞り込みが食い違えば、索引は使われない。
  # 組織で等値に絞り、そのうえで終了時刻の範囲を見る形であることを押さえる。
  test "一覧の絞り込みが索引の並びと同じ" do
    sql = organizations(:main).reservations.starting_from(Time.current).to_sql

    assert_includes sql, %q("reservations"."organization_id" = )
    assert_includes sql, %q("reservations"."ends_at" >= )
  end

  # 既存の索引は残す。重なりの判定とデータベース側の制約が依存する。
  test "設備ごとの開始時刻の索引を残している" do
    assert_includes indexes.map(&:name), "index_reservations_on_resource_id_and_starts_at"
  end

  # 進行中の予約は終了していない。開始済みであることを理由に外さない。
  test "指定した時刻に進行中の予約が一覧へ残る" do
    now = Time.current
    ongoing = create_reservation(starts_at: now - 30.minutes, ends_at: now + 30.minutes)
    finished = create_reservation(starts_at: now - 3.hours, ends_at: now - 2.hours)

    listed = Reservation.starting_from(now).pluck(:id)

    assert_includes listed, ongoing.id
    assert_not_includes listed, finished.id
  end

  private
    def indexes
      ActiveRecord::Base.connection.indexes(:reservations)
    end

    def create_reservation(starts_at:, ends_at:)
      organizations(:main).reservations.create!(
        resource: resources(:meeting_room_b), reserver: users(:taro),
        starts_at: starts_at, ends_at: ends_at, purpose: "打ち合わせ"
      )
    end
end
