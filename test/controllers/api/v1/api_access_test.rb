require "test_helper"

module Api
  module V1
    class ApiAccessTest < ActionDispatch::IntegrationTest
      include QueryCountTestHelper

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

      test "from を指定すると、その時刻以降の予定だけを返す" do
        get api_v1_events_url(from: 3.days.from_now.change(hour: 0).iso8601), headers: auth_headers

        assert_response :success

        titles = response.parsed_body["events"].map { |item| item["title"] }

        assert_includes titles, events(:taro_private).title
        assert_not_includes titles, events(:company_meeting).title
      end

      test "from を指定しないと現在時刻以降の予定を返す" do
        get api_v1_events_url, headers: auth_headers

        titles = response.parsed_body["events"].map { |item| item["title"] }

        assert_includes titles, events(:company_meeting).title
        assert_not_includes titles, events(:past_event).title
      end

      test "空の from は未指定として扱う" do
        get api_v1_events_url(from: ""), headers: auth_headers

        assert_response :success

        titles = response.parsed_body["events"].map { |item| item["title"] }

        assert_includes titles, events(:company_meeting).title
        assert_not_includes titles, events(:past_event).title
      end

      # 解析できない入力を既定値へ読み替えると、呼び出す側は誤りに
      # 気付かないまま、意図と異なる結果を受け取る。
      test "解析できない from は 400 で返す" do
        [ "2024-13-45", "abc", "9999999999999-01-01" ].each do |value|
          get api_v1_events_url(from: value), headers: auth_headers

          assert_response :bad_request, "from=#{value} が 400 になっていません"
          assert_equal "invalid_parameter", response.parsed_body["error"]
          assert_equal "from", response.parsed_body["parameter"]
        end
      end

      test "部門を取得できる" do
        get api_v1_departments_url, headers: auth_headers

        codes = response.parsed_body["departments"].map { |item| item["code"] }

        assert_includes codes, departments(:sales).code
        assert_not_includes codes, departments(:other_general).code
      end

      test "部門の階層を返す" do
        get api_v1_departments_url, headers: auth_headers

        paths = response.parsed_body["departments"].to_h { |item| [ item["code"], item["path"] ] }

        assert_equal "営業部 / 営業部 東日本課", paths[departments(:sales_east).code]
        assert_equal "開発部", paths[departments(:development).code]
      end

      # 部門の件数と階層の深さだけを変えて、同じ取得を 2 回数える。
      test "部門の取得で出る問い合わせが、件数と階層の深さで増えない" do
        # 最初の取得は token の最終利用を記録する。2 回目以降は間隔で
        # 間引かれるため、数える前に 1 度通しておく。
        get api_v1_departments_url, headers: auth_headers

        before = count_queries { get api_v1_departments_url, headers: auth_headers }

        add_department_chain(depth: 5)

        after = count_queries { get api_v1_departments_url, headers: auth_headers }

        assert_equal before, after
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

        def add_department_chain(depth:)
          parent = nil

          depth.times do |level|
            parent = organizations(:main).departments.create!(
              name: "追加の部門 #{level}", code: "extra-#{level}", parent: parent
            )
          end
        end
    end
  end
end
