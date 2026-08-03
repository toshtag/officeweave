require "test_helper"

# 語句が、書いたとおりに読まれることを固定する。
#
# YAML は引用符の無い yes、no、on、off を真偽値として読む。鍵がそうなると
# I18n が探す名前と一致せず、その語句を引けない。値がそうなると、画面へ
# 真偽値がそのまま出る。引用符の外にある " #" 以降はコメントとして落ちる。
#
# いずれも例外にならず、その 1 か所だけが崩れる。実際、主たる所属の
# 「はい／いいえ」は鍵が引けず、英語では値まで真偽値になっていた。
# 宛先の URL に # を含む場合の理由は、3 か所が途中で切れていた。
class LocaleReadingTest < ActiveSupport::TestCase
  LOCALES = %i[ja en].freeze
  # 鍵と値を 1 行で書いた並び。行頭の空白、鍵、コロン、値の順に見る。
  ENTRY = /\A\s*("?[\w.]+"?):[ \t]+(\S.*)\z/
  QUOTES = %w[" '].freeze

  test "語句の鍵は、すべて文字列として読まれる" do
    LOCALES.each do |locale|
      converted = entries_of(locale).reject { |_, key, _| key.is_a?(String) }

      assert_empty paths_of(converted), "#{locale}: 文字列ではない鍵がある"
    end
  end

  test "語句の値は、すべて文字列として読まれる" do
    LOCALES.each do |locale|
      converted = entries_of(locale).reject do |_, _, value|
        # 入れ子は語句そのものではなく、その下をたどる対象である。
        value.is_a?(String) || value.is_a?(Hash)
      end

      assert_empty paths_of(converted), "#{locale}: 文字列ではない値がある"
    end
  end

  # 読み込んだ値からは、切れたのか元から短いのかを判別できない。書いた行を見る。
  test "値に # を書く語句は、引用符で囲まれている" do
    LOCALES.each do |locale|
      truncated = lines_of(locale).filter_map do |line, number|
        next unless line =~ ENTRY

        value = $2.rstrip
        next if value.start_with?(*QUOTES)

        "#{locale}.yml:#{number}" if value.include?(" #")
      end

      assert_empty truncated, "#{locale}: # 以降がコメントとして落ちる語句がある"
    end
  end

  private
    def entries_of(locale)
      body = YAML.safe_load_file(path_of(locale), aliases: true)

      walk(body.fetch(locale.to_s))
    end

    # 改行は落とす。残すと行末の照合が外れ、何も見つけないまま成功する。
    def lines_of(locale) = path_of(locale).readlines(chomp: true).each_with_index.map { |line, i| [ line, i + 1 ] }

    def path_of(locale) = Rails.root.join("config/locales/#{locale}.yml")

    # 経路、鍵、値の 3 つ組を集める。鍵そのものを見るため、経路だけでは足りない。
    def walk(node, path = [], collected = [])
      node.each do |key, value|
        here = path + [ key.to_s ]

        collected << [ here.join("."), key, value ]
        walk(value, here, collected) if value.is_a?(Hash)
      end

      collected
    end

    def paths_of(entries) = entries.map { |path, _, _| path }
end
