require "test_helper"

# 上限の数え上げの置き場所。
#
# 置き場所を指定しない上限は、その web の内側で数える。web を 2 つに
# 増やせば、利用者から見た上限は 2 倍になる。上限を足すときに指定を
# 書き忘れると、その入口だけが台数に依存した状態へ戻る。
#
# 制御部の定義には、あとから読み取れる登録簿が無い。書いてある内容を
# 直接見る。
class RateLimitStoreTest < ActiveSupport::TestCase
  CONTROLLERS = Rails.root.glob("app/controllers/**/*.rb").freeze

  DECLARATION = /^\s*rate_limit\b/

  test "上限を宣言する制御部が 1 つ以上ある" do
    assert_operator declarations.size, :>=, 1
  end

  test "すべての上限が共有の置き場所で数える" do
    declarations.each do |path, source|
      assert_includes source, "store: RateLimitStore",
                      "#{path} の rate_limit が置き場所を指定していない。" \
                      "指定しないと、その web の内側で数え、台数だけ上限が増える"
    end
  end

  test "後始末の登録がある" do
    schedule = YAML.load_file(Rails.root.join("config/recurring.yml"))

    commands = schedule.fetch("production").values.filter_map { |entry| entry["command"] }

    assert_includes commands, "RateLimitCounter.delete_expired"
  end

  private
    # 1 つの宣言は複数行にまたがる。次の宣言か、宣言以外の行の始まりまでを
    # ひとまとまりとして取り出す。
    def declarations
      CONTROLLERS.flat_map do |path|
        blocks(path.read).map { |block| [ path.relative_path_from(Rails.root).to_s, block ] }
      end
    end

    def blocks(source)
      lines = source.lines
      starts = lines.each_index.select { |index| lines[index].match?(DECLARATION) }

      starts.map do |start|
        following = lines[(start + 1)..].take_while { |line| line.match?(/\A\s{2,}\S/) && !line.match?(DECLARATION) }
        (lines[start, 1] + following).join
      end
    end
end
