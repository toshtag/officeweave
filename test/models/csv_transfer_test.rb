require "test_helper"

class CsvTransferTest < ActiveSupport::TestCase
  DANGEROUS_VALUES = [
    "=1+1", "+SUM(1,1)", "-1+1", "@SUM(1,1)",
    "\t=1+1", "\r=1+1", "\n=1+1",
    "＝1+1", "＋1", "－1", "＠SUM"
  ].freeze

  SAFE_VALUES = [ "normal", "abc=1", "a+b", "山田 太郎", "", "10" ].freeze

  QUOTE_LEADING_VALUES = [ "'", "'=literal", "'normal", "''normal", "'''normal" ].freeze

  test "数式として解釈され得る値を単一引用符で始める" do
    DANGEROUS_VALUES.each do |value|
      assert_equal "'#{value}", cell(value)
    end
  end

  test "保護した値は 1 つのセルに収まり元の値へ戻る" do
    DANGEROUS_VALUES.each do |value|
      row = raw_row(value)

      assert_equal 2, row.fields.length
      assert_equal value, roundtrip(value)
    end
  end

  test "危険な文字が途中にあるだけの値は変えない" do
    SAFE_VALUES.each do |value|
      assert_equal value, cell(value)
      assert_equal value, roundtrip(value)
    end
  end

  test "数値は通常の文字列として書き出す" do
    assert_equal "10", cell(10)
    assert_equal "'-10", cell(-10)
  end

  test "nil は空欄として書き出す" do
    assert_nil CsvTransfer.escape(nil)
    assert_equal "", cell(nil)
  end

  test "元の値を変えない" do
    value = "=1+1"

    CsvTransfer.escape(value)

    assert_equal "=1+1", value
  end

  test "元から単一引用符で始まる値は単一引用符を 1 つ足して往復する" do
    QUOTE_LEADING_VALUES.each do |value|
      assert_equal "'#{value}", cell(value)
      assert_equal value, roundtrip(value)
    end
  end

  test "区切り文字と引用符と改行を含む値を 1 つのセルとして往復する" do
    [ "a,b", %(a"b), "a\nb", %(=1+2";=1+2), %(=1+2'",=1+2) ].each do |value|
      row = raw_row(value)

      assert_equal 2, row.fields.length
      assert_equal "x", row["b"]
      assert_equal value, roundtrip(value)
    end
  end

  test "見出しとデータセルをすべて二重引用符で囲む" do
    output = CsvTransfer.generate(headers: %w[a b]) { |csv| csv << [ "x", nil ] }

    assert_equal %("a","b"\n"x",""\n), output
  end

  test "見出しは復元しない" do
    table = CsvTransfer.parse(%("'=name"\n"'=1+1"\n))

    assert_equal [ "'=name" ], table.headers
    assert_equal "=1+1", table.first["'=name"]
  end

  test "形式が壊れた内容では解析の誤りをそのまま伝える" do
    assert_raises(CSV::MalformedCSVError) { CsvTransfer.parse(%(name\n"壊れた行,x\n)) }
  end

  test "アプリケーションのコードで標準の CSV を直接呼ばない" do
    offenders = Dir.glob(Rails.root.join("app/**/*.rb")).select do |path|
      path != Rails.root.join("app/models/csv_transfer.rb").to_s &&
        File.read(path).match?(/\bCSV\.(generate|parse)\b/)
    end

    assert_empty offenders
  end

  private
    # 保護そのものを確かめるため、書き出した内容は標準の CSV として読む。
    def raw_row(value)
      CSV.parse(generate(value), headers: true).first
    end

    def cell(value)
      raw_row(value)["a"]
    end

    def roundtrip(value)
      CsvTransfer.parse(generate(value)).first["a"]
    end

    def generate(value)
      CsvTransfer.generate(headers: %w[a b]) { |csv| csv << [ value, "x" ] }
    end
end
