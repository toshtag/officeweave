require "test_helper"

# 組み立てのたびに残るものを固定する。
#
# 組み立ての文脈へ入れたものは、配布するイメージへ入り、組み立ての記録にも
# 残る。生成物や開発専用の設定は、どちらにも要らない。
#
# イメージへ何を入れるかは test/configuration/container_build_test.rb が扱う。
# ここで扱うのは、入れないと決めたものが実際に外れているかである。
class ContainerLeftoverTest < ActiveSupport::TestCase
  IGNORE = Rails.root.join(".dockerignore").freeze
  DEVELOPMENT_IGNORE = Rails.root.join("Dockerfile.dockerignore").freeze

  # このリポジトリ自身の手順が書き出すもの。組み立てのたびに内容が変わる。
  GENERATED_DIRECTORIES = %w[scan_report/ load_report/].freeze

  # 手元でだけ使う設定と、ホスト側で実行する手順。
  DEVELOPMENT_ONLY = %w[
    .rubocop.yml
    .gitignore
    compose.browser.yaml
    compose.database.yaml
    script/
  ].freeze

  test "組み立ての文脈へ生成物を入れない" do
    missing = GENERATED_DIRECTORIES - ignored_entries

    assert_empty missing, ".dockerignore に無い: #{missing.join(', ')}"
  end

  test "組み立ての文脈へ開発専用のものを入れない" do
    missing = DEVELOPMENT_ONLY - ignored_entries

    assert_empty missing, ".dockerignore に無い: #{missing.join(', ')}"
  end

  test "開発用の組み立てには依存の定義だけを渡す" do
    # 開発用のイメージはソースを写さない。渡す必要があるのは、依存を解決する
    # ための 2 つだけである。それ以外を渡すと、使わないものが組み立ての記録へ残る。
    assert DEVELOPMENT_IGNORE.exist?, "Dockerfile.dockerignore が無い"

    entries = DEVELOPMENT_IGNORE.readlines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") }

    assert_equal [ "*", "!Gemfile", "!Gemfile.lock" ], entries
  end

  private
    def ignored_entries
      IGNORE.readlines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
    end
end
