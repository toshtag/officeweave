require "test_helper"

# 語句が、書いたとおりの文字列として読まれることを固定する。
#
# YAML は引用符の無い yes、no、on、off を真偽値として読む。鍵がそうなると
# I18n が探す名前と一致せず、その語句を引けない。値がそうなると、画面へ
# 真偽値がそのまま出る。どちらも例外にならず、その 1 か所だけが崩れる。
#
# 実際、主たる所属の「はい／いいえ」がこの状態で残っていた。鍵は引けず、
# 英語では値まで真偽値になっていた。
class LocaleReadingTest < ActiveSupport::TestCase
  LOCALES = %i[ja en].freeze

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

  private
    def entries_of(locale)
      body = YAML.safe_load_file(Rails.root.join("config/locales/#{locale}.yml"), aliases: true)

      walk(body.fetch(locale.to_s))
    end

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
