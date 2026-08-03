require "test_helper"

# 依存を解決する道具の版の決め方を固定する。
#
# 正本は Gemfile.lock の BUNDLED WITH とする。コンテナの定義へ版を書き写すと、
# lock を上げたときに片方だけが古いまま残る。組み立てたイメージが、lock を
# 書いたものと違う道具で依存を解決する状態になり、それに気づけない。
class BundlerVersionTest < ActiveSupport::TestCase
  LOCKFILE = Rails.root.join("Gemfile.lock").freeze

  DOCKERFILES = [
    Rails.root.join("Dockerfile"),
    Rails.root.join("Dockerfile.production")
  ].freeze

  test "使う版を Gemfile.lock が記録している" do
    assert_match(/^BUNDLED WITH\n\s+\d+\.\d+\.\d+\n/, LOCKFILE.read)
  end

  test "コンテナの定義は道具を明示して入れる" do
    # 基盤のイメージに含まれる版に任せると、それが変わったときに
    # 依存の解決だけが黙って別の道具へ移る。
    DOCKERFILES.each do |path|
      assert_match(/gem install bundler/, path.read, "#{path.basename} が道具を入れていない")
    end
  end

  test "入れる版は Gemfile.lock から読む" do
    DOCKERFILES.each do |path|
      commands = install_commands(path)
      # 命令を 1 件も拾えない状態で、条件を満たしたことにしない。
      assert_not_empty commands, "#{path.basename} から命令を拾えていない"

      commands.each do |command|
        assert_match(/Gemfile\.lock/, command,
          "#{path.basename} が lock を読まずに版を決めている: #{command}")
      end
    end
  end

  test "入れる版をコンテナの定義へ書き写さない" do
    DOCKERFILES.each do |path|
      commands = install_commands(path)
      assert_not_empty commands, "#{path.basename} から命令を拾えていない"

      commands.each do |command|
        assert_no_match(/\d+\.\d+\.\d+/, command,
          "#{path.basename} が版を書き写している: #{command}")
      end
    end
  end

  test "実行する側にも道具が入る" do
    # 配布用は組み立てと実行を別の段に分ける。組み立て側にだけ入れると、
    # 実行する側は基盤のイメージに含まれる版で lock を読むことになる。
    production = Rails.root.join("Dockerfile.production")

    assert_equal production.read.scan(/^FROM /).size, install_commands(production).size,
      "配布用の各段に道具が入っていない"
  end

  private
    # RUN の行から、道具を入れている命令だけを取り出す。
    # 行の継続（\ で終わる）をまたぐため、論理的な 1 命令へ組み直してから読む。
    def install_commands(path)
      path.read
        .gsub(/\\\n\s*/, " ")
        .lines
        .grep(/gem install bundler/)
        .map(&:strip)
    end
end
