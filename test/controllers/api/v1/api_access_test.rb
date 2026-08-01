require "test_helper"

module Api
  module V1
    class ApiAccessTest < ActionDispatch::IntegrationTest
      setup do
        @token = organizations(:main).api_tokens.create!(user: users(:taro), name: "連携用")
        @member_token = organizations(:main).api_tokens.create!(user: users(:hanako), name: "一般利用者用")
      end

      test "token がないと拒否される" do
        get api_v1_announcements_url

        assert_response :unauthorized
        assert_match "Bearer", response.headers["WWW-Authenticate"]
      end

      test "知らない token では拒否される" do
        get api_v1_announcements_url, headers: { "Authorization" => "Bearer unknown" }

        assert_response :unauthorized
      end

      test "形式が違う指定では拒否される" do
        get api_v1_announcements_url, headers: { "Authorization" => @token.token }

        assert_response :unauthorized
      end

      test "お知らせを取得できる" do
        get api_v1_announcements_url, headers: auth_headers

        assert_response :success

        titles = response.parsed_body["announcements"].map { |item| item["title"] }

        assert_includes titles, announcements(:company_wide).title
        assert_not_includes titles, announcements(:draft).title
      end

      test "公開範囲は token の持ち主に従う" do
        get api_v1_announcements_url, headers: auth_headers(@member_token)

        titles = response.parsed_body["announcements"].map { |item| item["title"] }

        assert_not_includes titles, announcements(:sales_only).title
      end

      test "予定を取得できる" do
        get api_v1_events_url, headers: auth_headers

        titles = response.parsed_body["events"].map { |item| item["title"] }

        assert_includes titles, events(:company_meeting).title
      end

      test "部門を取得できる" do
        get api_v1_departments_url, headers: auth_headers

        codes = response.parsed_body["departments"].map { |item| item["code"] }

        assert_includes codes, departments(:sales).code
        assert_not_includes codes, departments(:other_general).code
      end

      test "利用者の一覧は管理者の token でだけ取得できる" do
        get api_v1_users_url, headers: auth_headers

        assert_response :success

        get api_v1_users_url, headers: auth_headers(@member_token)

        assert_response :forbidden
      end

      test "無効にした token では取得できない" do
        @token.revoke!

        get api_v1_announcements_url, headers: auth_headers

        assert_response :unauthorized
      end

      # 値は発行時に一度だけ受け取る。無効化のあとで取り直せる経路は無い。
      test "再び有効にしても無効化前の token では取得できず、発行し直せば取得できる" do
        get api_v1_announcements_url, headers: auth_headers(@member_token)

        assert_response :success

        users(:hanako).deactivate!
        users(:hanako).activate!

        get api_v1_announcements_url, headers: auth_headers(@member_token)

        assert_response :unauthorized

        reissued = organizations(:main).api_tokens.create!(user: users(:hanako), name: "再発行")

        get api_v1_announcements_url, headers: auth_headers(reissued)

        assert_response :success

        get api_v1_announcements_url, headers: auth_headers(@member_token)

        assert_response :unauthorized
      end

      private
        def auth_headers(token = @token)
          { "Authorization" => "Bearer #{token.token}" }
        end
    end
  end
end
