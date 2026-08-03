require "test_helper"

# 実行されない生成物を残さないこと。
#
# 設計原則は、内容を伴わないファイルやディレクトリを、配置を先に確定する目的で
# 作成しないと定めている（docs/development/architecture.md）。
#
# 実行されない生成物は、検索したときに採用済みの実装と見分けが付かない。
# 途中まで実装済みに見え、次に同じ領域へ着手する人が、その時点の要件ではなく
# 生成された時点の雛形から始めることになる。
class GeneratedPlaceholderTest < ActiveSupport::TestCase
  # 中身を持たないディレクトリを Git へ残すための .keep。
  #
  # 実行環境が作った .keep を数えない。tmp/pids/.keep は開発環境が
  # 動くうちに作られるが、Git は追跡していない。ファイルシステムから
  # 一覧を作ると、手元では成立し、取得したままの作業ツリーでは成立しない
  # 一覧になる。実際、それで CI が失敗した（#178）。
  KEEP_FILES = %w[
    app/assets/images/.keep
    log/.keep
    storage/.keep
    tmp/.keep
    vendor/.keep
  ].freeze

  # 中身を持つため、.keep を置かないディレクトリ。
  DIRECTORIES_WITHOUT_KEEP = %w[
    app/controllers/concerns
    app/models/concerns
    lib/tasks
    script
    test/controllers
    test/fixtures/files
    test/helpers
    test/mailers
    test/models
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

  # 中身のあるディレクトリでは、.keep は何も保っていない。
  test "中身のあるディレクトリに .keep が残らない" do
    remaining = DIRECTORIES_WITHOUT_KEEP.select { |directory| keep_in(directory).exist? }

    assert_empty remaining, "中身があるのに .keep が残っている"
  end

  # 消しすぎると、中身を持たないディレクトリが Git から消える。
  test "中身を持たないディレクトリの .keep は残る" do
    missing = KEEP_FILES.reject { |path| Rails.root.join(path).exist? }

    assert_empty missing, ".keep が消えている"
  end

  # 一覧が実態から外れると、上の 2 件は何も確かめないまま成功する。
  # 中身が無くなったディレクトリは、.keep を消す側ではなく残す側へ移る。
  #
  # 逆向き（.keep を残す側に中身が無いこと）は、ファイルの有無では確かめられない。
  # log、storage、tmp は実行時にファイルが作られる。Git が追跡していないことは、
  # ファイルシステムからは読み取れない。
  test "「.keep を置かない」と決めたディレクトリに中身がある" do
    empty = DIRECTORIES_WITHOUT_KEEP.reject { |directory| Rails.root.glob("#{directory}/*").any? }

    assert_empty empty, "中身が無いため、.keep を残す側へ移す"
  end

  private
    def keep_in(directory)
      Rails.root.join(directory, ".keep")
    end
end
