require "test_helper"

# 部門の CSV 取り込み。
#
# 階層の指定が絡むため、行の並びに依存させない。上位を後ろの行で定義しても
# 取り込めるようにする。並びを守らせると、書き出したものをそのまま
# 戻せない場合がある。
#
# 1 行でも誤りがあれば何も保存しない。一部だけ取り込まれると、
# どこまで反映されたか分からなくなる。
class DepartmentCsvImportTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:main)
  end

  test "新しい部門を作る" do
    result = import(<<~CSV)
      name,code,parent_code,position
      "広報部","public-relations","","10"
    CSV

    assert_predicate result, :success?
    assert_equal 1, result.created_count

    created = @organization.departments.find_by(code: "public-relations")
    assert_equal "広報部", created.name
    assert_equal 10, created.position
    assert_nil created.parent
  end

  test "既にある部門は識別子で見つけて更新する" do
    existing = departments(:development)

    result = import(<<~CSV)
      name,code,parent_code,position
      "開発部（改称）","#{existing.code}","","5"
    CSV

    assert_predicate result, :success?
    assert_equal 1, result.updated_count
    assert_equal "開発部（改称）", existing.reload.name
    assert_equal 5, existing.position
  end

  test "上位部門を識別子で結び付ける" do
    result = import(<<~CSV)
      name,code,parent_code,position
      "本部","head","",""
      "第一課","first","head",""
    CSV

    assert_predicate result, :success?
    assert_equal @organization.departments.find_by(code: "head"),
                 @organization.departments.find_by(code: "first").parent
  end

  test "上位が後ろの行にあっても取り込める" do
    # 書き出しの並びは position と名前で決まる。上位が先に来るとは限らない。
    result = import(<<~CSV)
      name,code,parent_code,position
      "第一課","first","head",""
      "本部","head","",""
    CSV

    assert_predicate result, :success?
    assert_equal @organization.departments.find_by(code: "head"),
                 @organization.departments.find_by(code: "first").parent
  end

  test "上位を空欄にすると最上位になる" do
    child = departments(:sales_east)

    result = import(<<~CSV)
      name,code,parent_code,position
      "#{child.name}","#{child.code}","",""
    CSV

    assert_predicate result, :success?
    assert_nil child.reload.parent
  end

  test "上位の列が無ければ階層を変えない" do
    child = departments(:sales_east)

    result = import(<<~CSV)
      name,code
      "#{child.name}","#{child.code}"
    CSV

    assert_predicate result, :success?
    assert_equal departments(:sales), child.reload.parent
  end

  test "知らない上位の識別子は誤りとする" do
    result = import(<<~CSV)
      name,code,parent_code,position
      "広報部","public-relations","does-not-exist",""
    CSV

    refute_predicate result, :success?
    assert_equal 2, result.errors.first[:line]
    assert_nil @organization.departments.find_by(code: "public-relations")
  end

  test "自分自身を上位に指定できない" do
    result = import(<<~CSV)
      name,code,parent_code,position
      "広報部","public-relations","public-relations",""
    CSV

    refute_predicate result, :success?
    assert_nil @organization.departments.find_by(code: "public-relations")
  end

  test "循環する指定は取り込まない" do
    result = import(<<~CSV)
      name,code,parent_code,position
      "甲","alpha","beta",""
      "乙","beta","alpha",""
    CSV

    refute_predicate result, :success?
    assert_nil @organization.departments.find_by(code: "alpha")
  end

  test "1 行でも誤りがあれば何も保存しない" do
    result = import(<<~CSV)
      name,code,parent_code,position
      "広報部","public-relations","",""
      "","no-name","",""
    CSV

    refute_predicate result, :success?
    assert_nil @organization.departments.find_by(code: "public-relations")
  end

  test "識別子が空の行は誤りとする" do
    result = import(<<~CSV)
      name,code,parent_code,position
      "広報部","","",""
    CSV

    refute_predicate result, :success?
    assert_equal 2, result.errors.first[:line]
  end

  test "同じ識別子が 2 行にあれば誤りとする" do
    # どちらが最後の状態なのかを、取り込む側が決めてはならない。
    result = import(<<~CSV)
      name,code,parent_code,position
      "広報部","public-relations","",""
      "宣伝部","public-relations","",""
    CSV

    refute_predicate result, :success?
    assert_equal 3, result.errors.first[:line]
  end

  test "他の組織の部門は対象にしない" do
    other = organizations(:other).departments.create!(name: "他社の部", code: "outside")

    result = import(<<~CSV)
      name,code,parent_code,position
      "取り込んだ部","outside","",""
    CSV

    assert_predicate result, :success?
    assert_equal 1, result.created_count
    assert_equal "他社の部", other.reload.name
    assert_equal 2, Department.where(code: "outside").count
  end

  test "書き出したものをそのまま戻せる" do
    exported = DepartmentCsv.new(@organization).export

    result = import(exported)

    assert_predicate result, :success?
    assert_equal @organization.departments.count, result.updated_count
    assert_equal departments(:sales), departments(:sales_east).reload.parent
  end

  test "保護用の文字は取り除いて保存する" do
    # 書き出しでは = で始まる値の先頭へ ' を付ける。戻すときに取り除く。
    protected_name = "'=1+1"

    result = import(<<~CSV)
      name,code,parent_code,position
      "#{protected_name}","formula","",""
    CSV

    assert_predicate result, :success?
    assert_equal "=1+1", @organization.departments.find_by(code: "formula").name
  end

  test "読めない CSV は誤りとして返す" do
    result = import(%(name,code\n"壊れた))

    refute_predicate result, :success?
    assert_equal 0, result.errors.first[:line]
  end

  private
    def import(content)
      DepartmentCsv.new(@organization).import(content)
    end
end
