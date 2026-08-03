require "test_helper"

# 組み立てのたびに残るものを固定する。
#
# 組み立ての文脈へ入れたものは、配布するイメージへ入り、組み立ての記録にも
# 残る。生成物や開発専用の設定は、どちらにも要らない。
#
# 何を外すかは、名前を書き並べずに実際のファイルから導く。書き並べると、
# 構成ファイルや道具の設定を足すたびにここも直すことになり、直し忘れた分だけ
# 検査が効かなくなる。増える側ではなく、残す側を挙げる。
#
# イメージへ何を入れるかは test/configuration/container_build_test.rb が扱う。
class ContainerLeftoverTest < ActiveSupport::TestCase
  ROOT = Rails.root

  IGNORE = ROOT.join(".dockerignore").freeze
  DEVELOPMENT_IGNORE = ROOT.join("Dockerfile.dockerignore").freeze

  # 実行時に読む隠しファイル。これ以外は、道具の設定として外す。
  RUNTIME_DOTFILES = %w[.env.example .ruby-version].freeze

  # このリポジトリ自身の手順が書き出すもの。組み立てのたびに内容が変わる。
  GENERATED_DIRECTORIES = %w[scan_report/ load_report/].freeze

  # ホスト側で実行する手順。止める、作り直す、書き出すといった操作を伴い、
  # コンテナへは Docker を渡さないため、中からは呼べない。
  HOST_ONLY_DIRECTORIES = %w[script/].freeze

  test "構成の定義を組み立ての文脈へ入れない" do
    # compose と Dockerfile は、組み立てる側が読むものである。
    # 組み立てた中身が自分の定義を抱える理由が無い。
    definitions = root_entries("compose*.yaml") + root_entries("Dockerfile*") + [ ".dockerignore" ]

    remaining = definitions - ignored_entries

    assert_empty remaining, ".dockerignore に無い: #{remaining.join(', ')}"
  end

  test "道具の設定を組み立ての文脈へ入れない" do
    # 隠しファイルは、道具を足すたびに増える。残す側だけを挙げ、
    # それ以外は外れていることを確かめる。
    remaining = root_entries(".*") - RUNTIME_DOTFILES - ignored_entries

    assert_empty remaining, ".dockerignore に無い: #{remaining.join(', ')}"
  end

  test "生成物とホスト側の手順を組み立ての文脈へ入れない" do
    missing = (GENERATED_DIRECTORIES + HOST_ONLY_DIRECTORIES) - ignored_entries

    assert_empty missing, ".dockerignore に無い: #{missing.join(', ')}"
  end

  test "開発用の組み立てには依存の定義だけを渡す" do
    # 開発用のイメージはソースを写さない。渡す必要があるのは、依存を解決する
    # ための 2 つだけである。それ以外を渡すと、使わないものが組み立ての記録へ残る。
    assert DEVELOPMENT_IGNORE.exist?, "Dockerfile.dockerignore が無い"

    assert_equal [ "*", "!Gemfile", "!Gemfile.lock" ], entries_of(DEVELOPMENT_IGNORE)
  end

  private
    # 根元にある名前。ディレクトリは末尾へ / を付け、.dockerignore の書き方へそろえる。
    def root_entries(pattern)
      Dir.glob(pattern, base: ROOT, flags: File::FNM_DOTMATCH)
        .reject { |name| [ ".", ".." ].include?(name) }
        .map { |name| ROOT.join(name).directory? ? "#{name}/" : name }
    end

    # 除外の指定。`!` で戻しているものは、外していないものとして扱う。
    def ignored_entries
      entries_of(IGNORE).reject { |line| line.start_with?("!") }.map { |line| line.delete_suffix("/*") }
    end

    def entries_of(path)
      path.readlines.map(&:strip).reject { |line| line.empty? || line.start_with?("#") }
    end
end
