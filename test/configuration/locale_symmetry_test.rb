require "test_helper"

# 日本語を正本とし、英語をそれに追随させる（開発規約 第 12 節）。
#
# 片方にだけある語句は、その場では失敗しない。fallback が日本語へ落ちるため、
# 英語の画面に、その 1 行だけ日本語が出る。日本語を読める人が確かめても
# 気付けない。実際、予定への指名の通知が、その状態で残っていた。
#
# ここに書くのは期待値ではなく関係である。2 つのロケールを互いに突き合わせて
# 導き、どちらにも語句の一覧を持たない。語句を 1 つ増やしても、この検査は
# 直さない。
class LocaleSymmetryTest < ActiveSupport::TestCase
  LOCALES = %i[ja en].freeze

  # Rails が英語の既定を持つもの。日本語だけを上書きする。
  #
  # 英語へ写すと、Rails 側の文面が変わっても、こちらの写しが古いまま残る。
  RAILS_DEFAULTS = %w[errors. activerecord.errors.].freeze

  test "日本語の語句は、英語にもある" do
    assert_empty translated_only_in_japanese, "英語に無い語句がある"
  end

  test "英語の語句は、日本語にもある" do
    assert_empty keys_of(:en) - keys_of(:ja), "日本語に無い語句がある"
  end

  # 上の 2 件は、除外の一覧が実態から外れても、何も確かめないまま成功する。
  # Rails の既定へ任せたものが無くなったら、除外もそこで終える。
  test "除外した接頭辞は、いずれも日本語にだけある語句を持つ" do
    unused = RAILS_DEFAULTS.reject do |prefix|
      (keys_of(:ja) - keys_of(:en)).any? { |key| key.start_with?(prefix) }
    end

    assert_empty unused, "日本語にだけある語句を持たない接頭辞がある"
  end

  private
    def translated_only_in_japanese
      (keys_of(:ja) - keys_of(:en)).reject do |key|
        RAILS_DEFAULTS.any? { |prefix| key.start_with?(prefix) }
      end
    end

    def keys_of(locale)
      body = YAML.safe_load_file(Rails.root.join("config/locales/#{locale}.yml"), aliases: true)

      paths(body.fetch(locale.to_s))
    end

    # 葉までの経路を集める。値そのものは見ない。
    def paths(node, prefix = [], collected = [])
      node.each do |key, value|
        path = prefix + [ key.to_s ]

        value.is_a?(Hash) ? paths(value, path, collected) : collected << path.join(".")
      end

      collected
    end
end
