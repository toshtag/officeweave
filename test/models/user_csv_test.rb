require "test_helper"

class UserCsvTest < ActiveSupport::TestCase
  setup { @csv = UserCsv.new(organizations(:main)) }

  test "自組織の利用者だけを書き出す" do
    output = @csv.export

    assert_includes output, users(:taro).email_address
    assert_not_includes output, users(:outsider).email_address
  end

  test "所属している部門の識別子を並べる" do
    output = @csv.export
    row = CSV.parse(output, headers: true).find { |r| r["email_address"] == users(:taro).email_address }

    assert_includes row["departments"].split, departments(:sales).code
  end

  test "新しい利用者を追加できる" do
    result = @csv.import(<<~CSV)
      name,email_address,role,locale,departments
      鈴木 一郎,ichiro@example.com,member,,sales
    CSV

    assert_predicate result, :success?
    assert_equal 1, result.created_count

    user = organizations(:main).users.find_by(email_address: "ichiro@example.com")

    assert_equal "鈴木 一郎", user.name
    assert_includes user.departments, departments(:sales)
  end

  test "既存の利用者は更新する" do
    result = @csv.import(<<~CSV)
      name,email_address,role,locale,departments
      山田 太郎（更新）,#{users(:taro).email_address},administrator,ja,development
    CSV

    assert_predicate result, :success?
    assert_equal 1, result.updated_count

    user = users(:taro).reload

    assert_equal "山田 太郎（更新）", user.name
    assert_equal [ departments(:development) ], user.departments
  end

  test "取り込みでパスワードは変わらない" do
    digest_before = users(:taro).password_digest

    @csv.import("name,email_address\n山田 太郎,#{users(:taro).email_address}\n")

    assert_equal digest_before, users(:taro).reload.password_digest
  end

  test "1 行でも誤りがあれば何も保存しない" do
    assert_no_difference -> { User.count } do
      @result = @csv.import(<<~CSV)
        name,email_address
        鈴木 一郎,ichiro@example.com
        ,broken@example.com
      CSV
    end

    assert_not_predicate @result, :success?
    assert_equal 3, @result.errors.first[:line]
  end

  test "形式が壊れた内容では理由を返す" do
    result = @csv.import(%(name,email_address\n"壊れた行,x\n))

    assert_not_predicate result, :success?
  end

  test "未知の部門コードは行の誤りとして取り込み全体を拒否する" do
    result = @csv.import(<<~CSV)
      name,email_address,role,locale,departments
      山田 太郎（更新）,#{users(:taro).email_address},administrator,ja,missing-department
    CSV

    assert_not_predicate result, :success?
    assert_equal 0, result.created_count
    assert_equal 0, result.updated_count
    assert_equal 2, result.errors.first[:line]
    assert_includes result.errors.first[:messages].join, "missing-department"

    user = users(:taro).reload

    assert_equal "山田 太郎", user.name
    assert_equal "administrator", user.role
    assert_nil user.locale
    assert_equal [ departments(:sales) ], user.departments
  end

  test "既知と未知の部門コードが混在しても部分反映しない" do
    result = @csv.import(<<~CSV)
      name,email_address,role,locale,departments
      山田 太郎,#{users(:taro).email_address},administrator,,sales missing-department development
    CSV

    assert_not_predicate result, :success?
    assert_includes result.errors.first[:messages].join, "missing-department"
    assert_equal [ departments(:sales) ], users(:taro).reload.departments
  end

  test "未知の部門コードを重複なく入力順で示す" do
    result = @csv.import(<<~CSV)
      name,email_address,role,locale,departments
      山田 太郎,#{users(:taro).email_address},administrator,,missing-a sales missing-b missing-a
    CSV

    assert_not_predicate result, :success?

    message = result.errors.first[:messages].join

    assert_includes message, "missing-a, missing-b"
    assert_equal 1, message.scan("missing-a").length
    assert_not_includes message, "sales"
  end

  test "別組織の部門コードは未知として拒否する" do
    result = @csv.import(<<~CSV)
      name,email_address,role,locale,departments
      鈴木 一郎,ichiro@example.com,member,,general
    CSV

    assert_not_predicate result, :success?
    assert_includes result.errors.first[:messages].join, "general"
    assert_nil organizations(:main).users.find_by(email_address: "ichiro@example.com")
  end

  test "未知の部門コードがある場合は他の正常な行も巻き戻す" do
    result = @csv.import(<<~CSV)
      name,email_address,role,locale,departments
      山田 太郎（更新）,#{users(:taro).email_address},member,ja,development
      鈴木 一郎,ichiro@example.com,member,,missing-department
    CSV

    assert_not_predicate result, :success?
    assert_equal 3, result.errors.first[:line]
    assert_equal 0, result.created_count
    assert_equal 0, result.updated_count

    user = users(:taro).reload

    assert_equal "山田 太郎", user.name
    assert_equal "administrator", user.role
    assert_nil user.locale
    assert_equal [ departments(:sales) ], user.departments
    assert_nil organizations(:main).users.find_by(email_address: "ichiro@example.com")
  end

  test "departments 列がなければ既存の所属を変えない" do
    result = @csv.import(<<~CSV)
      name,email_address,role,locale
      山田 太郎（更新）,#{users(:taro).email_address},administrator,ja
    CSV

    assert_predicate result, :success?

    user = users(:taro).reload

    assert_equal "山田 太郎（更新）", user.name
    assert_equal "ja", user.locale
    assert_equal [ departments(:sales) ], user.departments
  end
end
