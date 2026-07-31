require "test_helper"

class DepartmentCsvTest < ActiveSupport::TestCase
  setup { @csv = DepartmentCsv.new(organizations(:main)) }

  test "自組織の部門だけを書き出す" do
    codes = exported_rows.map { |row| row["code"] }

    assert_includes codes, departments(:sales).code
    assert_not_includes codes, departments(:other_general).code
  end

  test "並び順と上位部門の識別子を保つ" do
    rows = exported_rows

    assert_equal organizations(:main).departments.ordered.map(&:code), rows.map { |row| row["code"] }

    row = rows.find { |r| r["code"] == departments(:sales_east).code }

    assert_equal departments(:sales).code, row["parent_code"]
  end

  test "数式として解釈され得る部門名を保護して書き出す" do
    [ "=1+1", "+SUM(1,1)", "-1+1", "@SUM(1,1)" ].each do |name|
      departments(:sales).update!(name: name)

      assert_equal "'#{name}", exported_row(departments(:sales))["name"]
    end
  end

  test "制御文字と全角の記号で始まる部門名を保護し 1 つのセルへ収める" do
    [ "\t=1+1", "\r=1+1", "\n=1+1", "＝1+1", "＋1", "－1", "＠SUM" ].each do |name|
      departments(:sales).update!(name: name)
      row = exported_row(departments(:sales))

      assert_equal "'#{name}", row["name"]
      assert_equal DepartmentCsv::HEADERS.length, row.fields.length
    end
  end

  test "区切り文字と引用符を含む部門名でも行や列が増えない" do
    departments(:sales).update!(name: %(=1+2";=1+2))
    rows = exported_rows
    row = rows.find { |r| r["code"] == departments(:sales).code }

    assert_equal organizations(:main).departments.count, rows.length
    assert_equal %('=1+2";=1+2), row["name"]
    assert_equal DepartmentCsv::HEADERS.length, row.fields.length
  end

  test "位置も同じ経路を通して書き出す" do
    departments(:sales).update!(position: -10)

    assert_equal "'-10", exported_row(departments(:sales))["position"]
  end

  private
    # 保護そのものを確かめるため、書き出した内容は標準の CSV として読む。
    def exported_rows
      CSV.parse(@csv.export, headers: true)
    end

    def exported_row(department)
      exported_rows.find { |row| row["code"] == department.code }
    end
end
