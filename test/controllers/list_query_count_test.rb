require "test_helper"

# 一覧が出す問い合わせの件数。
#
# 性能の退行は、件数が並べる記録の数に比例して増える形で現れる。関連を 1 件
# ずつ引くと、数件の一覧では気づかず、1 ページに並べる件数だけ倍になる。
#
# 期待値へ絶対の件数を書かない。書くと、無関係な変更のたびに書き換えが要る。
# 記録を増やして 2 回数え、増えないことで確かめる。
#
# 既に確かめている一覧はここへ重ねない。文書は document_list_test.rb、
# お知らせは announcement_list_test.rb、利用者は user_list_test.rb、
# 入口は home_unread_test.rb と home_request_test.rb が扱う。
class ListQueryCountTest < ActionDispatch::IntegrationTest
  include QueryCountTestHelper

  # 増やす記録の数。1 件ずつ引く作りなら、この数だけ問い合わせが増える。
  ADDED = 10

  setup do
    sign_in_as users(:taro)
    @password_digest = BCrypt::Password.create("password-for-tests", cost: BCrypt::Engine::MIN_COST)
  end

  test "予定の一覧の問い合わせが件数に比例して増えない" do
    assert_stable_query_count(events_url, marker: "予定") { |index| create_event(index) }
  end

  test "予約の一覧の問い合わせが件数に比例して増えない" do
    assert_stable_query_count(reservations_url, marker: "用途") { |index| create_reservation(index) }
  end

  test "申請の一覧の問い合わせが件数に比例して増えない" do
    assert_stable_query_count(requests_url, marker: "申請") { |index| create_request(index) }
  end

  test "通知の一覧の問い合わせが件数に比例して増えない" do
    assert_stable_query_count(notifications_url, marker: "お知らせ") { |index| create_notification(index) }
  end

  test "設備・備品の一覧の問い合わせが件数に比例して増えない" do
    assert_stable_query_count(resources_url, marker: "設備") { |index| create_resource(index) }
  end

  test "部門の一覧の問い合わせが件数に比例して増えない" do
    assert_stable_query_count(departments_url, marker: "部門") { |index| create_department(index) }
  end

  test "監査記録の一覧の問い合わせが件数に比例して増えない" do
    assert_stable_query_count(audit_events_url, marker: "記録の主") { |index| create_audit_event(index) }
  end

  private
    # 1 件だけ足した状態と、さらに増やした状態で数え、同じであることを確かめる。
    #
    # 0 件との比較にはしない。並ぶ記録が無い一覧は関連を引かないため、
    # 増えても増えないように見える。
    def assert_stable_query_count(url, marker:)
      yield(0)
      warm_up(url)

      before = count_queries { get url }

      ADDED.times { |index| yield(index + 1) }

      after = count_queries { get url }

      # 増やした記録が実際に並んでいることを確かめる。並ばない記録で数えると、
      # 関連を引かないまま「増えていない」という結果になる。実際、参照できない
      # 申請を作っていたときは、先読みを外しても件数が変わらなかった。
      assert_includes response.body, "#{marker} #{ADDED}",
                      "増やした記録が一覧に並んでいない（#{url}）"

      assert_equal before, after,
                   "記録を #{ADDED} 件増やして問い合わせが #{after - before} 件増えた（#{url}）"
    end

    # 数える前に 1 度実行する。初回は翻訳や画面の読み込みが混ざる。
    def warm_up(url)
      get url
    end

    # 結び付ける記録は 1 件ずつ別にする。
    #
    # 同じ相手にすると、1 件ずつ引く作りでも 2 回目以降が問い合わせの
    # キャッシュから返り、増えていないように見える。実際、同じ所有者で
    # 書いていたときは、先読みを外しても件数が変わらなかった。
    def create_event(index)
      start = Date.current.next_day.change(hour: 9) + index.hours

      current_organization.events.create!(
        owner: create_user(index), title: "予定 #{index}", starts_at: start,
        ends_at: start + 30.minutes, visibility: "organization"
      )
    end

    def create_user(index, name: "利用者 #{index}")
      current_organization.users.create!(
        name: name, email_address: "member#{index}@example.com",
        password_digest: @password_digest
      )
    end

    def create_reservation(index)
      # 日を分ける。同じ設備の同じ時間帯は重ねられない。
      # 一覧が読む期間の内側へ収める。外へ出すと、増やした記録が並ばない。
      start = (Date.current + 1 + index).to_time.change(hour: 9)

      current_organization.reservations.create!(
        resource: create_resource(index), reserver: create_user(index),
        purpose: "用途 #{index}", starts_at: start, ends_at: start + 30.minutes
      )
    end

    # 参照できる形で作る。下書きは申請者本人しか見られず、一覧に並ばない。
    # 提出済みで、かつ閲覧者が承認を担当する種別のものだけが並ぶ。
    def create_request(index)
      current_organization.requests.create!(
        request_type: request_types(:leave), applicant: create_user(index),
        title: "申請 #{index}", body: "内容", status: "pending", submitted_at: Time.current
      )
    end

    def create_notification(index)
      users(:taro).notifications.create!(
        event: "announcement_published", subject: create_announcement(index)
      )
    end

    def create_announcement(index)
      current_organization.announcements.create!(
        author: create_user(index), title: "お知らせ #{index}", body: "本文",
        visibility: "organization", published_at: Time.current
      )
    end

    def create_resource(index)
      current_organization.resources.create!(
        name: "設備 #{index}", code: "resource#{index}", capacity: index + 1
      )
    end

    def create_department(index)
      current_organization.departments.create!(name: "部門 #{index}", code: "dept#{index}")
    end

    def create_audit_event(index)
      # 一覧に並ぶのは行為者の名前である。名前で並びを確かめる。
      actor = create_user(index, name: "記録の主 #{index}")

      current_organization.audit_events.create!(
        actor: actor, action: "user_created", target_type: "User", target_id: actor.id
      )
    end

    def current_organization
      organizations(:main)
    end
end
