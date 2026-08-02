require "csv"

# CSV の受け渡し。
#
# 表計算ソフトは、= + - @ で始まるセルを数式として評価することがある。
# OfficeWeave は利用者名や部門名に記号の制限を設けていないため、保護しない
# まま書き出すと、入力された値が受け取った側で数式として解釈され、意図しない
# 外部参照や動作を起こし得る。実際の挙動は製品と版と取り込み設定によって違う。
#
# 危険な開始文字を持つ値には単一引用符を前置する。これは表計算ソフトが必ず
# 従う規約ではなく、最初に開いたときに数式として評価させないための措置である。
# 万能ではないため、OfficeWeave が保証するのは次の 2 点に限る。
#
#   1. 書き出したデータセルが危険な文字から始まらないこと
#   2. OfficeWeave が書き出した CSV を戻せば、元の値へ復元できること
#
# 2 を成立させるため、単一引用符は転送形式のエスケープ文字として扱う。
# 元から単一引用符で始まる値には、もう 1 つ足して区別する。取り込みでは
# 足した 1 層だけを戻す。
#
# 生成と解析をここへ集約する。片方だけを直すと、書き出しと取り込みで
# 前置文字の意味が食い違い、往復するたびに値が変わる。
class CsvTransfer
  ESCAPE_PREFIX = "'"

  # 先頭の 1 文字だけを見る。前後の空白を取り除いてから判定しない。
  # 利用者が入力した値を、推測で整形しないためである。
  DANGEROUS_PREFIX = /\A[=+\-@\t\r\n＝＋－＠]/

  # 呼出側へ標準の CSV writer を渡さない。渡すと、保護を通らない行を
  # 書ける経路が残る。
  class Writer
    def initialize(csv)
      @csv = csv
    end

    def <<(values)
      @csv << values.map { |value| CsvTransfer.escape(value) }
      self
    end
  end

  class << self
    # 区切り文字と引用符の扱いは標準の CSV に任せる。自前で置き換えると、
    # 表記の幅を取りこぼす。すべてのフィールドを引用し、値の見た目が
    # 列の切れ目に影響しないようにする。
    def generate(headers:)
      CSV.generate(headers: headers, write_headers: true, force_quotes: true) do |csv|
        yield Writer.new(csv)
      end
    end

    # 書き出し先を渡す形。件数が多い場合に、全体をメモリへ載せずに済む。
    #
    # 生成の指定は generate と同じものを使う。片方だけを変えると、
    # 渡し方によって引用の仕方が違う CSV が出る。
    def write(io, headers:)
      csv = CSV.new(io, headers: headers, write_headers: true, force_quotes: true)

      yield Writer.new(csv)

      io
    end

    # 見出しは復元しない。見出しのある形式だけを扱うのは、見出しが無いと
    # どの行を復元すべきかを区別できないためである。
    #
    # CSV::MalformedCSVError は握り潰さない。呼出側が誤りの理由として扱う。
    def parse(content)
      CSV.parse(content, headers: true).tap do |table|
        table.each do |row|
          row.each_with_index { |(_header, value), index| row[index] = unescape(value) }
        end
      end
    end

    def escape(value)
      return nil if value.nil?

      text = value.to_s

      return text unless text.start_with?(ESCAPE_PREFIX) || text.match?(DANGEROUS_PREFIX)

      "#{ESCAPE_PREFIX}#{text}"
    end

    # 判定の順序を入れ替えない。'' で始まる値は、元から単一引用符で
    # 始まっていた値であり、危険な文字が続いていても 1 つだけ取り除く。
    def unescape(value)
      return value unless value.is_a?(String)

      if value.start_with?(ESCAPE_PREFIX * 2)
        value.delete_prefix(ESCAPE_PREFIX)
      elsif value.start_with?(ESCAPE_PREFIX) && value.delete_prefix(ESCAPE_PREFIX).match?(DANGEROUS_PREFIX)
        value.delete_prefix(ESCAPE_PREFIX)
      else
        value
      end
    end
  end
end
