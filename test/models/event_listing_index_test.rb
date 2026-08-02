require "test_helper"

# 予定の一覧が使う索引。
#
# 一覧は指定日以降に終わる予定へ絞る。終了済みの予定は消えないため、
# その条件に合う索引が無いと、走査する量が運用の期間に比例して増える。
class EventListingIndexTest < ActiveSupport::TestCase
  ENDS_AT_INDEX = "index_events_on_organization_id_and_ends_at".freeze

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
    sql = Event.where(organization_id: organizations(:main).id)
               .starting_from(Time.current).to_sql

    assert_includes sql, %q("events"."organization_id" = )
    assert_includes sql, %q("events"."ends_at" >= )
  end

  # 既存の索引は残す。日付を指定した参照と並び順がこれに依存し得る。
  test "開始時刻の索引を残している" do
    assert_includes indexes.map(&:name), "index_events_on_organization_id_and_starts_at"
  end

  # 進行中の予定は終了していない。開始済みであることを理由に外さない。
  test "指定した時刻に進行中の予定が一覧へ残る" do
    now = Time.current
    ongoing = create_event("進行中の予定", starts_at: now - 1.hour, ends_at: now + 1.hour)
    finished = create_event("終わった予定", starts_at: now - 3.hours, ends_at: now - 2.hours)

    listed = Event.starting_from(now).pluck(:id)

    assert_includes listed, ongoing.id
    assert_not_includes listed, finished.id
  end

  private
    def indexes
      ActiveRecord::Base.connection.indexes(:events)
    end

    def create_event(title, starts_at:, ends_at:)
      organizations(:main).events.create!(
        owner: users(:taro), title: title, starts_at: starts_at, ends_at: ends_at,
        visibility: "organization"
      )
    end
end
