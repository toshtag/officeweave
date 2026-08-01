require "test_helper"

class SessionTest < ActiveSupport::TestCase
  include QueryCountTestHelper

  CREATED_AT = Time.zone.parse("2026-07-31 09:00:00").freeze
  CHECKED_AT = (CREATED_AT + 4.hours).freeze

  setup { @user = users(:taro) }

  test "作成した時刻を基準に 2 つの時刻が決まる" do
    session = create_session

    assert_equal CREATED_AT, session.last_active_at
    assert_equal CREATED_AT + Session::ABSOLUTE_TIMEOUT, session.expires_at
  end

  test "絶対期限の直前は有効" do
    session = create_session
    at = CREATED_AT + Session::ABSOLUTE_TIMEOUT - 1.second
    session.record_activity!(at: at)

    assert session.active?(at: at)
  end

  test "直前まで操作していても絶対期限ちょうどで無効になる" do
    session = create_session
    at = CREATED_AT + Session::ABSOLUTE_TIMEOUT
    session.record_activity!(at: at - 1.second)

    assert session.expired?(at: at)
  end

  test "最終利用から無操作期限までは有効" do
    session = create_session

    assert session.active?(at: CREATED_AT + Session::IDLE_TIMEOUT - 1.second)
  end

  test "最終利用から無操作期限ちょうどで無効になる" do
    session = create_session

    assert session.expired?(at: CREATED_AT + Session::IDLE_TIMEOUT)
  end

  test "活動を記録すると最終利用日時が進む" do
    session = create_session
    activity_at = CREATED_AT + 20.minutes

    session.record_activity!(at: activity_at)

    assert_equal activity_at, session.reload.last_active_at
  end

  test "活動を記録しても絶対期限は延びない" do
    session = create_session
    expires_at = session.expires_at

    session.record_activity!(at: CREATED_AT + 20.minutes)

    assert_equal expires_at, session.reload.expires_at
  end

  test "活動を記録すると無操作期限の起点が移る" do
    session = create_session

    session.record_activity!(at: CREATED_AT + 20.minutes)

    assert session.active?(at: CREATED_AT + 40.minutes)
  end

  # 認証済みの要求はすべてこの記録を更新する。1 回ごとに書くと、画面を
  # 表示するだけの要求まで書き込みを伴う。
  test "短い間隔で続けて記録しても書き込まない" do
    session = create_session
    at = CREATED_AT + 10.minutes
    session.record_activity!(at: at)

    assert_equal 0, count_queries { session.record_activity!(at: at + 30.seconds) }
  end

  test "間隔を超えると記録される" do
    session = create_session
    at = CREATED_AT + 10.minutes
    session.record_activity!(at: at)
    later = at + Session::ACTIVITY_WRITE_INTERVAL + 1.second

    session.record_activity!(at: later)

    assert_equal later, session.reload.last_active_at
  end

  # 書かなかった分だけ記録は過去のままになる。期限は早く来ることはあっても、
  # 遅く来ることはない。認証が緩む向きには働かない。
  test "書き込みを省いても無操作の期限は延びない" do
    session = create_session
    at = CREATED_AT + 10.minutes
    session.record_activity!(at: at)
    session.record_activity!(at: at + 30.seconds)

    assert session.expired?(at: at + Session::IDLE_TIMEOUT)
  end

  test "期限切れの絞り込みは絶対期限と無操作期限の両方を対象にする" do
    absolute, idle, active = build_expiration_scenario

    expired = Session.expired(at: CHECKED_AT)

    assert_includes expired, absolute
    assert_includes expired, idle
    refute_includes expired, active
  end

  test "定期削除は期限切れだけを消す" do
    _absolute, _idle, active = build_expiration_scenario

    deleted = Session.delete_expired(at: CHECKED_AT)

    assert_equal 2, deleted
    assert_equal [ active ], Session.all.to_a
  end

  test "定期削除を繰り返しても失敗しない" do
    build_expiration_scenario

    Session.delete_expired(at: CHECKED_AT)

    assert_equal 0, Session.delete_expired(at: CHECKED_AT)
  end

  private
    def create_session(at: CREATED_AT)
      travel_to(at) { @user.sessions.create! }
    end

    # 2 つの期限を独立して確かめるため、片方だけを超えたセッションを用意する。
    # 作成時刻を揃えると、無操作期限を超えたものが絶対期限も同時に超える。
    def build_expiration_scenario
      absolute = create_session(at: CHECKED_AT - Session::ABSOLUTE_TIMEOUT)
      absolute.record_activity!(at: CHECKED_AT - 1.minute)

      idle = create_session
      idle.record_activity!(at: CHECKED_AT - Session::IDLE_TIMEOUT)

      active = create_session
      active.record_activity!(at: CHECKED_AT - 1.minute)

      [ absolute, idle, active ]
    end
end
