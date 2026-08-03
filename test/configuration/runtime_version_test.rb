require "test_helper"

# 実行環境の版の決め方を固定する。
#
# 同じ値が複数の定義ファイルに現れる。Docker の FROM は組み立ての前にファイルを
# 読めないため、1 か所へまとめきれない。まとめられない分は、食い違ったときに
# 気づける形にする。
#
# 依存を解決する道具のように、正本から読み取れるものは
# test/configuration/bundler_version_test.rb が扱う。
class RuntimeVersionTest < ActiveSupport::TestCase
  ROOT = Rails.root

  DOCKERFILES = [ ROOT.join("Dockerfile"), ROOT.join("Dockerfile.production") ].freeze

  COMPOSE_FILES = [ ROOT.join("compose.yaml"), ROOT.join("compose.production.yaml") ].freeze

  test "Ruby の版が実行環境の定義ファイルで一致する" do
    # 書き方の違いをここで吸収しない。接頭辞を剥がして比べると、定義場所ごとに
    # 別の書き方が残ったままになり、そろっているかどうかを目で確かめられない。
    versions = DOCKERFILES.to_h { |path| [ path.basename.to_s, ruby_version_in(path) ] }
      .merge(".ruby-version" => ROOT.join(".ruby-version").read.strip)

    assert_not_includes versions.values, nil, "版を拾えない定義ファイルがある: #{versions.inspect}"
    assert_equal 1, versions.values.uniq.size, "版が食い違っている: #{versions.inspect}"
  end

  test "構成ファイルは Ruby の版を書き直さない" do
    # 組み立ての既定は Dockerfile が持つ。構成ファイルから重ねて渡すと、
    # 同じ値が増えるだけで、渡さない側（配布用）との食い違いも生む。
    restated = COMPOSE_FILES.flat_map do |path|
      path.readlines.grep(/RUBY_VERSION/).map { |line| "#{path.basename}: #{line.strip}" }
    end

    assert_empty restated
  end

  test "開発用と配布用が同じデータベースのイメージを使う" do
    images = COMPOSE_FILES.to_h { |path| [ path.basename.to_s, database_image_in(path) ] }

    assert_not_includes images.values, nil, "イメージを拾えない構成ファイルがある: #{images.inspect}"
    assert_equal 1, images.values.uniq.size, "イメージが食い違っている: #{images.inspect}"
  end

  test "取り込むクライアントの系列がデータベースの系列と一致する" do
    # 版が違うと、スキーマ定義の書き出しとバックアップの取得が失敗する。
    server = database_image_in(COMPOSE_FILES.first)[/postgres:(\d+)/, 1]

    assert_not_nil server, "データベースのイメージから系列を読めない"

    DOCKERFILES.each do |path|
      clients = path.read.scan(/^ARG POSTGRESQL_MAJOR_VERSION=(\d+)$/).flatten

      assert_not_empty clients, "#{path.basename} がクライアントの系列を指定していない"
      assert_equal [ server ], clients.uniq,
        "#{path.basename} のクライアントが #{server} 系ではない: #{clients.inspect}"
    end
  end

  private
    def ruby_version_in(path)
      path.read[/^ARG RUBY_VERSION=(\S+)$/, 1]
    end

    def database_image_in(path)
      path.read[/^\s+image:\s*(postgres:\S+)$/, 1]
    end
end
