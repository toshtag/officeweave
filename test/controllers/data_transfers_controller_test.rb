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

  test "ファイルを選ばない場合は理由が示される" do
    sign_in_as users(:taro)

    post users_import_url

    assert_redirected_to data_transfers_path
  end

  private
    def csv_file(content)
      Rack::Test::UploadedFile.new(StringIO.new(content), "text/csv", original_filename: "users.csv")
    end
end
