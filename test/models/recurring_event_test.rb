require "test_helper"

# 繰り返し予定。
#
# 各回を独立した予定として作る。規則だけを持って読むときに展開する形は
# 採らない。参照範囲、予約との結び付き、参加者の指名は、いずれも予定 1 件を
# 対象にしており、展開する形にすると、それらすべてが規則を知る必要がある。
#
# 各回は独立して直せる。1 回だけ時間を変えることが実務では起きる。
class RecurringEventTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:main)
    @owner = users(:taro)
  end

  test "毎週の繰り返しを作る" do
    series = create_series(frequency: "weekly", repeat_until: 3.weeks.from_now.to_date)

    assert_equal 4, series.size
    assert_equal [ 0, 7, 14, 21 ],
                 series.map { |event| (event.starts_at.to_date - series.first.starts_at.to_date).to_i }
  end

  test "毎日の繰り返しを作る" do
    series = create_series(frequency: "daily", repeat_until: 2.days.from_now.to_date)

    assert_equal 3, series.size
  end

  test "毎月の繰り返しを作る" do
    series = create_series(frequency: "monthly", repeat_until: 2.months.from_now.to_date)

    assert_equal 3, series.size
    assert_equal series.first.starts_at.day, series.last.starts_at.day
  end

  test "繰り返しの終わりを超えない" do
    repeat_until = 10.days.from_now.to_date
    series = create_series(frequency: "weekly", repeat_until: repeat_until)

    assert_operator series.last.starts_at.to_date, :<=, repeat_until
  end

  test "各回は同じ内容を持つ" do
    series = create_series(frequency: "daily", repeat_until: 2.days.from_now.to_date,
                           attributes: { title: "定例会", visibility: "organization" })

    assert_equal [ "定例会" ], series.map(&:title).uniq
    assert_equal [ "organization" ], series.map(&:visibility).uniq
    assert_equal [ 1 ], series.map { |event| ((event.ends_at - event.starts_at) / 1.hour).to_i }.uniq
  end

  test "各回は同じ参加者を持つ" do
    series = create_series(frequency: "daily", repeat_until: 1.day.from_now.to_date,
                           participants: [ users(:hanako) ])

    assert_equal [ [ users(:hanako).id ] ], series.map { |event| event.participants.map(&:id) }.uniq
  end

  test "同じ繰り返しの回は互いを辿れる" do
    series = create_series(frequency: "daily", repeat_until: 2.days.from_now.to_date)

    assert_equal series.map(&:id).sort, series.first.series_events.map(&:id).sort
    assert_predicate series.first, :recurring?
  end

  test "繰り返しを指定しなければ 1 件だけ作る" do
    series = create_series(frequency: nil, repeat_until: nil)

    assert_equal 1, series.size
    refute_predicate series.first, :recurring?
  end

  test "上限を超える回数は作らない" do
    event = build_event
    result = Event::Recurrence.new(event, frequency: "daily",
                                          repeat_until: (Event::Recurrence::MAXIMUM_OCCURRENCES + 5).days.from_now.to_date)

    assert_not result.valid?
    assert_includes result.errors.attribute_names, :repeat_until
  end

  test "終わりが開始より前の指定は作らない" do
    event = build_event
    result = Event::Recurrence.new(event, frequency: "weekly", repeat_until: Date.current - 1)

    assert_not result.valid?
  end

  test "知らない間隔は作らない" do
    event = build_event
    result = Event::Recurrence.new(event, frequency: "hourly", repeat_until: 1.week.from_now.to_date)

    assert_not result.valid?
    assert_includes result.errors.attribute_names, :frequency
  end

  test "1 回だけ直しても他の回は変わらない" do
    series = create_series(frequency: "daily", repeat_until: 2.days.from_now.to_date)
    moved = series.second

    moved.update!(title: "この回だけ変更")

    assert_equal [ "定例", "この回だけ変更", "定例" ], series.map { |event| event.reload.title }
  end

  test "このあとの回をまとめて消せる" do
    series = create_series(frequency: "daily", repeat_until: 3.days.from_now.to_date)

    assert_difference -> { Event.count }, -3 do
      series.second.destroy_following
    end

    assert Event.exists?(series.first.id)
  end

  test "1 回だけ消しても他の回は残る" do
    series = create_series(frequency: "daily", repeat_until: 2.days.from_now.to_date)

    series.second.destroy

    assert_equal 2, Event.where(id: series.map(&:id)).count
  end

  private
    def build_event(attributes = {})
      @organization.events.new({
        owner: @owner, title: "定例", visibility: "private",
        starts_at: 1.day.from_now.change(hour: 9, min: 0, sec: 0),
        ends_at: 1.day.from_now.change(hour: 10, min: 0, sec: 0)
      }.merge(attributes))
    end

    # 繰り返しを作り、開始の順に返す。
    def create_series(frequency:, repeat_until:, attributes: {}, participants: [])
      event = build_event(attributes)
      recurrence = Event::Recurrence.new(event, frequency: frequency, repeat_until: repeat_until)

      assert recurrence.save(participants: participants), recurrence.errors.full_messages.to_sentence

      Event.where(id: [ event.id ] + Event.where(series_id: event.series_id).pluck(:id))
           .distinct.chronological.to_a
    end
end
