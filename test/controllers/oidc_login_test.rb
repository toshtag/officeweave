require "test_helper"
require_relative "../test_helpers/local_http_server_test_helper"
require_relative "../test_helpers/local_certificate_test_helper"
require_relative "../test_helpers/oidc_provider_test_helper"

# OIDC でのログイン。
#
# 認可サーバーが返した id_token を、この製品の利用者へ結び付ける。
# 利用者は自動で作らない。作ると、認可サーバーへ登録された相手が、
# この製品の組織へそのまま入れる。
class OidcLoginTest < ActionDispatch::IntegrationTest
  include LocalHttpServerTestHelper
  include OidcProviderTestHelper

  # 443 番で待ち受けるため、他の worker と重ならないようにする。
  self.use_transactional_tests = false

  setup do
    Authentication::Oidc::Client.reset_cache!
    @user = users(:hanako)
    @user.update!(email_address: "person@example.com")
  end

  teardown do
    Authentication::Oidc.client_factory = nil
    ENV.delete("AUTHENTICATION_PROVIDER")
    Officeweave::Configuration::Oidc::VARIABLES.each { |name| ENV.delete(name) }
    Session.delete_all
    AuditEvent.delete_all
  end

  test "設定が無ければ扱えない" do
    post oidc_session_url
    assert_response :not_found

    get oidc_callback_url(code: "a-code", state: "a-state")
    assert_response :not_found
  end

  test "ログイン画面に認可サーバーへの入口が出る" do
    with_oidc_login do
      get new_session_url

      assert_response :success
      assert_select "form[action=?][method=post]", oidc_session_path
      # 資格情報はこの製品の中に無い。入力欄は出さない。
      assert_select "input[name=password]", count: 0
    end
  end

  test "内部認証では入口を出さない" do
    get new_session_url

    assert_select "form[action=?]", oidc_session_path, count: 0
  end

  test "認可サーバーへ転送する" do
    with_oidc_login do |provider|
      post oidc_session_url

      assert_response :redirect
      location = URI.parse(response.location)
      query = URI.decode_www_form(location.query).to_h

      assert_equal "#{provider.issuer}/authorize", "#{location.scheme}://#{location.host}#{location.path}"
      assert_equal "code", query["response_type"]
      assert query["state"].present?
      assert query["nonce"].present?
      assert query["code_challenge"].present?
      assert_equal oidc_callback_url, query["redirect_uri"]
    end
  end

  test "認可サーバーの応答からログインできる" do
    with_oidc_login do |provider|
      sign_in_with_oidc(provider)

      assert_redirected_to root_path
      assert_equal 1, @user.sessions.count
    end
  end

  test "ログインを監査記録へ残す" do
    with_oidc_login do |provider|
      sign_in_with_oidc(provider)

      event = AuditEvent.with_action("signed_in").recent_first.first

      assert_equal @user, event.actor
      # どの方式で入ったのかが分からないと、経路を絞れない。
      assert_equal "oidc", event.details["provider"]
    end
  end

  test "state が違えばログインしない" do
    with_oidc_login do |provider|
      start_authorization
      get oidc_callback_url(code: "a-code", state: "another-state")

      assert_redirected_to new_session_path
      assert_equal 0, @user.sessions.count
    end
  end

  test "開始していない受け取りは扱わない" do
    with_oidc_login do
      get oidc_callback_url(code: "a-code", state: "a-state")

      assert_redirected_to new_session_path
      assert_equal 0, @user.sessions.count
    end
  end

  test "一度使った state は二度使えない" do
    with_oidc_login do |provider|
      sign_in_with_oidc(provider)
      state = @state
      delete session_url

      get oidc_callback_url(code: "a-code", state: state)

      assert_redirected_to new_session_path
    end
  end

  test "認可サーバーが拒否を返した場合はログインしない" do
    with_oidc_login do
      state = start_authorization

      get oidc_callback_url(error: "access_denied", state: state)

      assert_redirected_to new_session_path
      assert_equal 0, @user.sessions.count
    end
  end

  test "id_token の検証が通らなければログインしない" do
    forged = { "/token" => { id_token: OidcProviderTestHelper.id_token(iss: "https://attacker.example.com") } }

    with_oidc_login(forged) do |provider|
      sign_in_with_oidc(provider)

      assert_redirected_to new_session_path
      assert_equal 0, @user.sessions.count
    end
  end

  test "nonce が違う id_token ではログインしない" do
    mismatched = { "/token" => { id_token: OidcProviderTestHelper.id_token(nonce: "another-nonce") } }

    with_oidc_login(mismatched) do |provider|
      sign_in_with_oidc(provider)

      assert_redirected_to new_session_path
      assert_equal 0, @user.sessions.count
    end
  end

  test "該当する利用者が居なければログインしない" do
    unknown = { "/token" => { id_token: OidcProviderTestHelper.id_token(email: "nobody@example.com") } }

    with_oidc_login(unknown) do |provider|
      sign_in_with_oidc(provider)

      assert_redirected_to new_session_path
      # 認可サーバーへ登録された相手が、この製品の組織へそのまま入れてはならない。
      assert_equal 0, User.where(email_address: "nobody@example.com").count
    end
  end

  test "無効化された利用者はログインできない" do
    @user.deactivate!

    with_oidc_login do |provider|
      sign_in_with_oidc(provider)

      assert_redirected_to new_session_path
      assert_equal 0, @user.sessions.count
    end
  end

  test "無効化された利用者の試みを監査記録へ残す" do
    @user.deactivate!

    with_oidc_login do |provider|
      sign_in_with_oidc(provider)

      event = AuditEvent.with_action("sign_in_failed").recent_first.first

      assert_not_nil event
      assert_nil event.actor
      assert_equal @user, event.target
      assert_equal "oidc", event.details["provider"]
    end
  end

  test "利用者を特定できない失敗は記録しない" do
    # どの組織の記録にもならない。内部認証の失敗と同じ扱いとする。
    unknown = { "/token" => { id_token: OidcProviderTestHelper.id_token(email: "nobody@example.com") } }

    with_oidc_login(unknown) do |provider|
      assert_no_difference -> { AuditEvent.count } do
        sign_in_with_oidc(provider)
      end
    end
  end

  test "保護された画面へ戻る" do
    with_oidc_login do |provider|
      get documents_url
      assert_redirected_to new_session_path

      sign_in_with_oidc(provider)

      assert_redirected_to documents_path
    end
  end

  private
    # OIDC を使う設定にして、認可サーバーを立てる。
    def with_oidc_login(responses = {}, &block)
      # token の応答を渡された場合は、そのまま使う。渡されない場合は、
      # 認可の開始で決まった nonce を含む id_token へ差し替える。
      @token_provided = responses.key?("/token")

      with_oidc_provider(responses) do |provider|
        ENV["AUTHENTICATION_PROVIDER"] = "oidc"
        ENV["OIDC_ISSUER"] = provider.issuer
        ENV["OIDC_CLIENT_ID"] = "officeweave"
        ENV["OIDC_CLIENT_SECRET"] = "a-client-secret"

        Authentication::Oidc.client_factory = lambda do |settings|
          Authentication::Oidc::Client.new(settings).tap do |client|
            client.certificate_store = LocalCertificateTestHelper.trusted.store
            client.resolver = oidc_resolver
          end
        end

        block.call(provider)
      end
    end

    # 認可を開始し、転送された先の state を返す。
    def start_authorization
      post oidc_session_url

      @state = URI.decode_www_form(URI.parse(response.location).query).to_h.fetch("state")
    end

    # 開始から受け取りまでを通す。
    #
    # nonce は開始のときに作られる。id_token はその値で組み立て直す。
    def sign_in_with_oidc(provider)
      post oidc_session_url
      query = URI.decode_www_form(URI.parse(response.location).query).to_h
      @state = query.fetch("state")

      rebuild_token(provider, query.fetch("nonce"))

      get oidc_callback_url(code: "a-code", state: @state)
    end

    # 既定の応答では nonce を埋められない。開始のあとに差し替える。
    def rebuild_token(provider, nonce)
      return if @token_provided

      provider.respond_with("/token", { id_token: OidcProviderTestHelper.id_token(nonce: nonce) })
    end
end
