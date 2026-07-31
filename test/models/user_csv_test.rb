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

  test "数式として解釈され得る利用者名を保護して書き出す" do
    [ "=1+1", "+SUM(1,1)", "-1+1", "@SUM(1,1)" ].each do |name|
      users(:taro).update!(name: name)

      assert_equal "'#{name}", exported_row(users(:taro))["name"]
    end
  end

  test "制御文字で始まる利用者名を保護し 1 つのセルへ収める" do
    [ "\t=1+1", "\r=1+1", "\n=1+1" ].each do |name|
      users(:taro).update!(name: name)
      row = exported_row(users(:taro))

      assert_equal "'#{name}", row["name"]
      assert_equal UserCsv::HEADERS.length, row.fields.length
    end
  end

  test "全角の記号で始まる利用者名を保護して書き出す" do
    [ "＝1+1", "＋1", "－1", "＠SUM" ].each do |name|
      users(:taro).update!(name: name)

      assert_equal "'#{name}", exported_row(users(:taro))["name"]
    end
  end

  test "記号が途中にあるだけの利用者名は変えない" do
    [ "山田=太郎", "山田+太郎", "山田 太郎@" ].each do |name|
      users(:taro).update!(name: name)

      assert_equal name, exported_row(users(:taro))["name"]
    end
  end

  test "区切り文字と引用符を含む利用者名でも列が増えない" do
    users(:taro).update!(name: %(=1+2";=1+2))
    row = exported_row(users(:taro))

    assert_equal %('=1+2";=1+2), row["name"]
    assert_equal UserCsv::HEADERS.length, row.fields.length
  end

  test "書き出した利用者 CSV を取り込むと元の値へ戻る" do
    users(:taro).update!(name: "=1+1", locale: "ja")
    output = @csv.export
    users(:taro).update!(name: "別の名前", locale: "en")

    result = @csv.import(output)

    assert_predicate result, :success?

    user = users(:taro).reload

    assert_equal "=1+1", user.name
    assert_equal "ja", user.locale
    assert_equal "administrator", user.role
    assert_equal "taro@example.com", user.email_address
    assert_equal [ departments(:sales) ], user.departments
  end

  test "元から単一引用符で始まる利用者名も往復できる" do
    [ "'", "'=literal", "'normal", "''normal" ].each do |name|
      users(:taro).update!(name: name)
      output = @csv.export
      users(:taro).update!(name: "別の名前")

      assert_predicate @csv.import(output), :success?
      assert_equal name, users(:taro).reload.name
    end
  end

  test "手作業で作った通常の CSV は記号を含んでいてもそのまま取り込む" do
    result = @csv.import(<<~CSV)
      name,email_address,role,locale,departments
      山田=太郎,#{users(:taro).email_address},administrator,,sales
    CSV

    assert_predicate result, :success?
    assert_equal "山田=太郎", users(:taro).reload.name
  end

  test "保護されていない値を取り込むと値のまま保存し次の書き出しで保護する" do
    result = @csv.import(<<~CSV)
      name,email_address,role,locale,departments
      =1+1,#{users(:taro).email_address},administrator,,sales
    CSV

    assert_predicate result, :success?
    assert_equal "=1+1", users(:taro).reload.name
    assert_equal "'=1+1", exported_row(users(:taro))["name"]
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

    result = @csv.import("name,email_address,role\n山田 太郎,#{users(:taro).email_address},administrator\n")

    assert_predicate result, :success?
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
    # 1 行目の降格そのものは誤りにしない。巻き戻す対象を残すため管理者を増やす。
    users(:hanako).update!(role: "administrator")

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

  test "departments 列を空欄にすると所属をすべて解除する" do
    result = @csv.import(<<~CSV)
      name,email_address,role,locale,departments
      山田 太郎,#{users(:taro).email_address},administrator,,
    CSV

    assert_predicate result, :success?
    assert_empty users(:taro).reload.departments
  end

  test "複数の部門コードを指定できる" do
    result = @csv.import(<<~CSV)
      name,email_address,role,locale,departments
      山田 太郎,#{users(:taro).email_address},administrator,,sales development
    CSV

    assert_predicate result, :success?
    assert_equal [ departments(:sales), departments(:development) ].sort_by(&:id),
                 users(:taro).reload.departments.sort_by(&:id)
  end

  test "最後の管理者を一般利用者へ変える取り込みは全体を拒否する" do
    result = @csv.import(<<~CSV)
      name,email_address,role,locale,departments
      山田 太郎（更新）,#{users(:taro).email_address},member,ja,development
    CSV

    assert_not_predicate result, :success?
    assert_equal 0, result.created_count
    assert_equal 0, result.updated_count
    assert_equal 2, result.errors.first[:line]
    assert_includes result.errors.first[:messages], last_active_administrator_message

    user = users(:taro).reload

    assert_equal "山田 太郎", user.name
    assert_equal "administrator", user.role
    assert_nil user.locale
    assert_equal [ departments(:sales) ], user.departments
  end

  test "権限を空欄にした取り込みでも最後の管理者を守る" do
    result = @csv.import(<<~CSV)
      name,email_address,role,locale,departments
      山田 太郎（更新）,#{users(:taro).email_address},,ja,development
    CSV

    assert_not_predicate result, :success?
    assert_includes result.errors.first[:messages], last_active_administrator_message

    user = users(:taro).reload

    assert_equal "山田 太郎", user.name
    assert_equal "administrator", user.role
    assert_nil user.locale
    assert_equal [ departments(:sales) ], user.departments
  end

  test "同じ取り込みで管理者を全員一般利用者へ変えられない" do
    users(:hanako).update!(role: "administrator")

    result = @csv.import(<<~CSV)
      name,email_address,role,locale
      山田 太郎（更新）,#{users(:taro).email_address},member,ja
      佐藤 花子（更新）,#{users(:hanako).email_address},member,ja
    CSV

    assert_not_predicate result, :success?
    assert_equal 3, result.errors.first[:line]
    assert_includes result.errors.first[:messages], last_active_administrator_message
    assert_equal 0, result.updated_count

    assert_equal "administrator", users(:taro).reload.role
    assert_equal "山田 太郎", users(:taro).name
    assert_equal "administrator", users(:hanako).reload.role
  end

  test "管理者が 2 人いれば取り込みで 1 人を一般利用者へ変えられる" do
    users(:hanako).update!(role: "administrator")

    result = @csv.import(<<~CSV)
      name,email_address,role,locale
      山田 太郎,#{users(:taro).email_address},member,
    CSV

    assert_predicate result, :success?
    assert_equal 1, result.updated_count
    assert_equal "member", users(:taro).reload.role
    assert_equal 1, organizations(:main).users.active.administrator.count
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

  private
    # 保護そのものを確かめるため、書き出した内容は標準の CSV として読む。
    def exported_row(user)
      CSV.parse(@csv.export, headers: true).find { |row| row["email_address"] == user.email_address }
    end

    def last_active_administrator_message
      I18n.t("activerecord.errors.models.user.attributes.base.last_active_administrator")
    end
end
