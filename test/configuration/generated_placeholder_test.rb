require "test_helper"

# 実行されない生成物を残さないこと。
#
# 設計原則は、内容を伴わないファイルやディレクトリを、配置を先に確定する目的で
# 作成しないと定めている（docs/architecture/principles.md）。
#
# 実行されない生成物は、検索したときに採用済みの実装と見分けが付かない。
# 途中まで実装済みに見え、次に同じ領域へ着手する人が、その時点の要件ではなく
# 生成された時点の雛形から始めることになる。
class GeneratedPlaceholderTest < ActiveSupport::TestCase
  # 追跡するファイルを持たないディレクトリ。空でも Git へ残す必要がある。
  # 実行時に作られるものと、まだ中身を置いていないものが含まれる。
  DIRECTORIES_KEPT_EMPTY = %w[
    app/assets/images
    log
    storage
    tmp
    tmp/pids
    vendor
  ].freeze

  test "経路を持たない画面の雛形が残らない" do
    assert_not Rails.root.join("app/views/pwa").exist?, "PWA の雛形が残っている"
  end

  # 経路が無いことも併せて見る。雛形だけを消して経路が残ると、
  # 次は 500 になる。
  test "PWA の経路が無い" do
    paths = Rails.application.routes.routes.map { |route| route.path.spec.to_s }

    assert_empty paths.grep(%r{manifest|service-worker}),
                 "PWA の経路が残っている"
  end

  test "画面が manifest と service worker を参照しない" do
    layout = Rails.root.join("app/views/layouts/application.html.erb").read

    assert_no_match(/manifest/, layout)
    assert_no_match(/serviceWorker/, layout)
  end

  # 例示のコメントだけの initializer は、設定済みに見えて何も設定しない。
  test "設定を行わない initializer が残らない" do
    empty = Rails.root.glob("config/initializers/*.rb").select do |path|
      path.readlines.none? { |line| line.match?(/\S/) && !line.match?(/\A\s*#/) }
    end

    assert_empty empty.map { |path| path.relative_path_from(Rails.root).to_s },
                 "実行される行を持たない initializer がある"
  end

  # 追跡するファイルを既に持つディレクトリでは、.keep は何も保っていない。
  test "追跡するファイルを持つディレクトリに .keep が残らない" do
    redundant = keep_files.select { |keep| tracked_files_in(keep.dirname).any? }

    assert_empty redundant.map { |keep| relative(keep) },
                 "追跡するファイルがあるのに .keep が残っている"
  end

  # 消しすぎると、実行時に作られるディレクトリが Git から消える。
  test "空のまま残すディレクトリの .keep は残る" do
    DIRECTORIES_KEPT_EMPTY.each do |directory|
      keep = Rails.root.join(directory, ".keep")

      assert keep.exist?, "#{directory}/.keep が消えている"
      assert_empty tracked_files_in(keep.dirname),
                   "#{directory} は追跡するファイルを持つため、この一覧から外す"
    end
  end

  private
    def keep_files
      Rails.root.glob("**/.keep")
    end

    def tracked_files_in(directory)
      relative = directory.relative_path_from(Rails.root)
      output = `git -C #{Rails.root} ls-files -- #{relative}`

      output.lines.map(&:chomp).reject { |path| path.end_with?("/.keep") }
    end

    def relative(path)
      path.relative_path_from(Rails.root).to_s
    end
end
