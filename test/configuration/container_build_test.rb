require "test_helper"

# イメージへ何を入れるかを固定する。
#
# 開発用と配布用では、ソースコードの届け方が違う。開発用はホストから共有し、
# 配布用はイメージへ取り込む。この違いを取り違えると、片方は書き換えが
# 反映されなくなり、もう片方は起動できなくなる。
#
# 名前の決め方は test/configuration/container_name_test.rb が扱う。
class ContainerBuildTest < ActiveSupport::TestCase
  DEVELOPMENT_DOCKERFILE = Rails.root.join("Dockerfile").freeze
  PRODUCTION_DOCKERFILE = Rails.root.join("Dockerfile.production").freeze

  DOCKERFILES = [ DEVELOPMENT_DOCKERFILE, PRODUCTION_DOCKERFILE ].freeze

  DEVELOPMENT_COMPOSE = YAML.safe_load_file(Rails.root.join("compose.yaml"), aliases: true).freeze

  APPLICATION_SERVICES = %w[web worker].freeze

  # 作業ディレクトリの全体を写す指定。
  SOURCE_COPY = /^COPY \. \.$/

  test "開発用のイメージはソースを写さない" do
    # 実行時は必ずホストの内容で覆われる。写しても、その場で捨てられるものを
    # 組み立てのたびに作ることになり、前のイメージが参照されないまま残る。
    assert_empty source_copies_in(DEVELOPMENT_DOCKERFILE)
  end

  test "開発用の構成はソースをホストから共有する" do
    # 写しを外せる前提そのものである。共有をやめるなら、写しを戻す必要がある。
    APPLICATION_SERVICES.each do |name|
      volumes = DEVELOPMENT_COMPOSE.dig("services", name, "volumes")

      assert_includes volumes, ".:/app", "#{name} がソースを共有していない"
    end
  end

  test "配布用のイメージはソースを写す" do
    # 配布先にはこのリポジトリが無い。共有できるものが存在しない。
    assert_not_empty source_copies_in(PRODUCTION_DOCKERFILE)
  end

  test "依存の解決の並列数を書き写さない" do
    # 依存を解決する道具は、指定が無ければ実行環境の処理装置の数を使う。
    # 書き写すと、その値より多い環境で頭打ちになり、少ない環境では過剰になる。
    # 版を上げても、書き写した値は追随しない。
    restated = DOCKERFILES.flat_map do |path|
      path.readlines.grep(/BUNDLE_JOBS/).map { |line| "#{path.basename}: #{line.strip}" }
    end

    assert_empty restated
  end

  test "配布用は取得したものを層へ残さない" do
    # 取得したものが層に残ると、配布するイメージがその分だけ大きくなる。
    content = PRODUCTION_DOCKERFILE.read

    missing = %w[/var/lib/apt/lists /usr/local/bundle/cache].reject do |target|
      content.include?("rm -rf #{target}")
    end

    assert_empty missing, "層から取り除いていない: #{missing.join(', ')}"
  end

  private
    def source_copies_in(path)
      path.readlines.grep(SOURCE_COPY).map(&:strip)
    end
end
