require "test_helper"

class DataTransfersControllerTest < ActionDispatch::IntegrationTest
  test "管理者は書き出せる" do
    sign_in_as users(:taro)

    get users_export_url

    assert_response :success
    assert_match "text/csv", response.headers["Content-Type"]
    assert_includes response.body, users(:taro).email_address
  end

  test "部門も書き出せる" do
    sign_in_as users(:taro)

    get departments_export_url

    assert_includes response.body, departments(:sales).code
  end

  test "書き出した利用者 CSV では数式として解釈され得る値が保護される" do
    users(:taro).update!(name: %(=1+2";=1+2))
    sign_in_as users(:taro)

    get users_export_url

    assert_response :success
    assert_match "text/csv", response.headers["Content-Type"]
    assert_match "users-#{Date.current.iso8601}.csv", response.headers["Content-Disposition"]

    row = parsed_rows.find { |r| r["email_address"] == users(:taro).email_address }

    assert_equal %('=1+2";=1+2), row["name"]
    assert_equal UserCsv::HEADERS.length, row.fields.length
    assert_not_includes parsed_rows.map { |r| r["email_address"] }, users(:outsider).email_address
  end

  test "書き出した部門 CSV では数式として解釈され得る値が保護される" do
    departments(:sales).update!(name: "@SUM(1,1)")
    sign_in_as users(:taro)

    get departments_export_url

    assert_response :success
    assert_match "text/csv", response.headers["Content-Type"]
    assert_match "departments-#{Date.current.iso8601}.csv", response.headers["Content-Disposition"]

    row = parsed_rows.find { |r| r["code"] == departments(:sales).code }

    assert_equal "'@SUM(1,1)", row["name"]
    assert_equal DepartmentCsv::HEADERS.length, row.fields.length
    assert_not_includes parsed_rows.map { |r| r["code"] }, departments(:other_general).code
  end

  test "一般利用者は扱えない" do
    sign_in_as users(:hanako)

    get data_transfers_url

    assert_response :forbidden
  end

  test "取り込みで利用者を追加できる" do
    sign_in_as users(:taro)

    assert_difference -> { User.count }, 1 do
      post users_import_url, params: { file: csv_file("name,email_address\n鈴木 一郎,ichiro@example.com\n") }
    end

    assert_redirected_to data_transfers_path
  end

  test "誤りがある場合は行番号と理由が示される" do
    sign_in_as users(:taro)

    assert_no_difference -> { User.count } do
      post users_import_url, params: { file: csv_file("name,email_address\n,broken@example.com\n") }
    end

    assert_response :unprocessable_content
    assert_select ".error-summary"
  end

  test "未知の部門コードは行番号と識別子を示して拒否される" do
    sign_in_as users(:taro)

    post users_import_url, params: { file: csv_file(<<~CSV) }
      name,email_address,role,locale,departments
      山田 太郎,#{users(:taro).email_address},administrator,ja,missing-department
    CSV

    assert_response :unprocessable_content
    assert_select ".error-summary" do
      assert_select "li", text: /#{Regexp.escape(I18n.t("data_transfers.import.line", line: 2))}/
      assert_select "li", text: /missing-department/
    end
    assert_not_includes response.body, I18n.t("data_transfers.imported", created: 0, updated: 0)
    assert_equal [ departments(:sales) ], users(:taro).reload.departments
  end

  test "最後の管理者を一般利用者へ変える取り込みは行番号と理由を示して拒否される" do
    sign_in_as users(:taro)

    assert_no_difference -> { AuditEvent.where(action: "users_imported").count } do
      post users_import_url, params: { file: csv_file(<<~CSV) }
        name,email_address,role,locale,departments
        山田 太郎（更新）,#{users(:taro).email_address},member,ja,development
      CSV
    end

    assert_response :unprocessable_content
    assert_select ".error-summary" do
      assert_select "li", text: /#{Regexp.escape(I18n.t("data_transfers.import.line", line: 2))}/
      assert_select "li", text: /#{Regexp.escape(last_active_administrator_message)}/
    end

    user = users(:taro).reload

    assert_equal "山田 太郎", user.name
    assert_equal "administrator", user.role
    assert_equal [ departments(:sales) ], user.departments
  end

  test "ファイルを選ばない場合は理由が示される" do
    sign_in_as users(:taro)

    post users_import_url

    assert_redirected_to data_transfers_path
  end

  private
    # 保護そのものを確かめるため、応答は標準の CSV として読む。
    def parsed_rows
      CSV.parse(response.body, headers: true)
    end

    def csv_file(content)
      Rack::Test::UploadedFile.new(StringIO.new(content), "text/csv", original_filename: "users.csv")
    end

    def last_active_administrator_message
      I18n.t("activerecord.errors.models.user.attributes.base.last_active_administrator")
    end
end
