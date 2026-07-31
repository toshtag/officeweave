require "test_helper"
require "ripper"

class CsvTransferTest < ActiveSupport::TestCase
  # 空白とコメントは、定数の直後にあっても参照の意味を変えない。
  IGNORED_TOKEN_TYPES = %i[
    on_sp on_nl on_ignored_nl on_comment on_embdoc_beg on_embdoc on_embdoc_end
  ].freeze

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

  test "共通経路の外から標準の CSV を参照すると検出する" do
    [
      %(CSV.generate(headers: []) { |csv| csv << [] }),
      %(CSV.parse(content, headers: true)),
      %(CSV.generate_line([ "=1" ])),
      %(CSV.open("x.csv", "w")),
      %(CSV.new(io)),
      %(CSV.read("x.csv")),
      %(CSV.foreach("x.csv")),
      %(CSV.parse_line("=1")),
      %(parser = CSV),
      %(::CSV.open("x.csv")),
      %(CSV("a,b"))
    ].each do |source|
      assert_equal [ 1 ], direct_csv_references(source), source
    end
  end

  test "誤りの種別の参照と、コメントや文字列の記述は検出しない" do
    [
      %(rescue CSV::MalformedCSVError),
      %(raise CSV::MalformedCSVError, "壊れている"),
      %(CSV ::MalformedCSVError),
      %(# CSV.generate は共通経路だけで使用する),
      %("CSV.open は使用しない")
    ].each do |source|
      assert_empty direct_csv_references(source), source
    end
  end

  test "検出した参照の行番号を示す" do
    source = <<~RUBY
      rescue CSV::MalformedCSVError
      CSV.open("x.csv")
    RUBY

    assert_equal [ 2 ], direct_csv_references(source)
  end

  test "標準 CSV の利用を CsvTransfer の外へ広げない" do
    allowed = Rails.root.join("app/models/csv_transfer.rb").to_s

    offenders = Dir.glob(Rails.root.join("app/**/*.rb")).reject { |path| path == allowed }.flat_map do |path|
      relative = Pathname.new(path).relative_path_from(Rails.root)

      direct_csv_references(File.read(path)).map { |line| "#{relative}:#{line}" }
    end

    assert_empty offenders
  end

  private
    # 迂回はメソッド名を列挙しても塞げない。CSV.generate と CSV.parse だけを
    # 探すと、generate_line、open、new、read、foreach、parse_line が素通りする。
    # 定数への参照そのものを字句として数え、許すのは誤りの種別だけとする。
    def direct_csv_references(source)
      tokens = Ripper.lex(source).reject { |(_position, type, _text, _state)| IGNORED_TOKEN_TYPES.include?(type) }

      tokens.each_index.filter_map do |index|
        position, type, text, = tokens[index]

        next unless type == :on_const && text == "CSV"
        next if malformed_csv_error_reference?(tokens, index)

        position.first
      end
    end

    def malformed_csv_error_reference?(tokens, index)
      _operator_position, operator_type, operator_text, = tokens[index + 1] || []
      _constant_position, constant_type, constant_text, = tokens[index + 2] || []

      operator_type == :on_op && operator_text == "::" &&
        constant_type == :on_const && constant_text == "MalformedCSVError"
    end

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
