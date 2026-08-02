require "test_helper"

# 部門の CSV 取り込みの経路。
#
# 既にある記録を書き換えるため、管理者へ限る。
class DepartmentCsvImportRequestTest < ActionDispatch::IntegrationTest
  test "管理者は取り込める" do
    sign_in_as users(:taro)

    assert_difference -> { organizations(:main).departments.count }, 1 do
      post departments_import_url, params: { file: upload(<<~CSV) }
        name,code,parent_code,position
        "広報部","public-relations","","10"
      CSV
    end

    assert_redirected_to data_transfers_path
  end

  test "一般利用者は取り込めない" do
    sign_in_as users(:hanako)

    assert_no_difference -> { Department.count } do
      post departments_import_url, params: { file: upload("name,code\n\"広報部\",\"pr\"\n") }
    end

    assert_response :forbidden
  end

  test "ファイルを選ばなければ知らせる" do
    sign_in_as users(:taro)

    post departments_import_url

    assert_redirected_to data_transfers_path
    assert_equal I18n.t("data_transfers.no_file"), flash[:alert]
  end

  test "誤りのある取り込みは行番号と理由を示す" do
    sign_in_as users(:taro)

    assert_no_difference -> { Department.count } do
      post departments_import_url, params: { file: upload(<<~CSV) }
        name,code,parent_code,position
        "広報部","public-relations","does-not-exist",""
      CSV
    end

    assert_response :unprocessable_content
    assert_includes response.body, "2"
  end

  test "取り込みを監査記録へ残す" do
    sign_in_as users(:taro)

    assert_difference -> { AuditEvent.with_action("departments_imported").count }, 1 do
      post departments_import_url, params: { file: upload(<<~CSV) }
        name,code,parent_code,position
        "広報部","public-relations","","10"
      CSV
    end

    event = AuditEvent.with_action("departments_imported").recent_first.first

    assert_equal 1, event.details["created"]
    assert_equal 0, event.details["updated"]
  end

  test "書き出しも記録へ残す" do
    # 部門の書き出しは、これまで記録に残っていなかった。
    sign_in_as users(:taro)

    assert_difference -> { AuditEvent.with_action("departments_exported").count }, 1 do
      get departments_export_url(format: :csv)
    end
  end

  test "取り込みの画面へ部門の欄がある" do
    sign_in_as users(:taro)

    get data_transfers_url

    assert_select "form[action=?]", departments_import_path
  end

  private
    def upload(content)
      Rack::Test::UploadedFile.new(StringIO.new(content), "text/csv", original_filename: "departments.csv")
    end
end
