require "test_helper"

# 認証のたびに起きる書き込み。
#
# 認証済みの要求はすべて、セッションの最終活動時刻を更新する。1 回ごとに
# 書くと、画面を表示するだけの要求まで書き込みを伴う。
class SessionActivityTest < ActionDispatch::IntegrationTest
  include QueryCountTestHelper

  setup { sign_in_as users(:taro) }

  test "続けて画面を開いても、活動の記録は毎回は書き込まれない" do
    get root_url

    assert_empty session_updates_in { get root_url }
  end

  test "間隔を超えて開くと、活動が記録される" do
    get root_url

    travel(Session::ACTIVITY_WRITE_INTERVAL + 1.second) do
      assert_not_empty session_updates_in { get root_url }
    end
  end

  test "書き込みを省いても、無操作の期限を過ぎればログインを求められる" do
    get root_url

    travel(Session::IDLE_TIMEOUT + 1.second) do
      get root_url

      assert_redirected_to new_session_path
    end
  end

  private
    def session_updates_in(&block)
      capture_queries(&block).select { |query| query[:sql].include?('UPDATE "sessions"') }
    end
end
