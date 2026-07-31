require "test_helper"

# 認証後の戻り先を、保存する側から押さえる。
class SessionReturnToTest < ActionDispatch::IntegrationTest
  test "保存する戻り先はパスとクエリだけになる" do
    get "/documents?query=manual"

    assert_redirected_to new_session_path
    assert_equal "/documents?query=manual", session[:return_to_after_authenticating]
  end

  test "別のホスト名で受けた要求でも戻り先にホストが残らない" do
    get "http://outside.example/documents"

    assert_equal "/documents", session[:return_to_after_authenticating]
  end
end

# 認証後の戻り先を、使用する側から押さえる。
#
# 保存する側を直しても、別の経路で書き込まれた値と、
# 修正前に保存された値が残る。使用する時点でも検査する。
class SessionReturnToUseTest < ActionController::TestCase
  tests SessionsController

  setup { @user = users(:taro) }

  test "保存済みの完全 URL では外部へ遷移しない" do
    sign_in_returning_to "https://outside.example/path"

    assert_redirected_to root_path
  end

  test "保存済みの平文の完全 URL でも外部へ遷移しない" do
    sign_in_returning_to "http://outside.example/path"

    assert_redirected_to root_path
  end

  test "保存済みのプロトコル相対の値では外部へ遷移しない" do
    sign_in_returning_to "//outside.example/path"

    assert_redirected_to root_path
  end

  test "保存済みの逆斜線を含む値では外部へ遷移しない" do
    sign_in_returning_to "/\\outside.example/path"

    assert_redirected_to root_path
  end

  test "保存済みのホスト名から始まる値では外部へ遷移しない" do
    sign_in_returning_to "outside.example/path"

    assert_redirected_to root_path
  end

  test "保存済みの空文字では応答を壊さない" do
    sign_in_returning_to ""

    assert_redirected_to root_path
  end

  test "保存済みの制御文字を含む値では応答を壊さない" do
    sign_in_returning_to "/documents\nSet-Cookie: injected=1"

    assert_redirected_to root_path
  end

  test "保存済みの解釈できない値では応答を壊さない" do
    sign_in_returning_to "/documents/["

    assert_redirected_to root_path
  end

  test "保存済みのアプリケーション内の経路へは戻る" do
    sign_in_returning_to "/documents?query=manual"

    assert_redirected_to "/documents?query=manual"
  end

  private
    def sign_in_returning_to(return_to)
      post :create,
           params: { email_address: @user.email_address, password: "password-for-tests" },
           session: { return_to_after_authenticating: return_to }
    end
end
