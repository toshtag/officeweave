require "test_helper"

# 規則そのものを、固定した題材で確かめる。
#
# いまのリポジトリの状態を読ませて確かめると、差が無い時期には何も確かめない
# まま通る。規則が壊れていても気付けない。
class ReleaseSourceTest < ActiveSupport::TestCase
  test "同じ commit なら、確かめる差そのものが無い" do
    source = ReleaseSource.new(tested: "abc1234", released: "abc1234")

    assert_predicate source, :same_tree?
    assert_predicate source, :valid?
    assert_match(/同じである/, source.summary)
  end

  test "記録だけが変わっているなら通す" do
    source = ReleaseSource.new(tested: "abc1234", released: "def5678",
                               changed_paths: [ "VERSION", "CHANGELOG.md", "README.md",
                                                "docs/releases/0.3.1_verification.md",
                                                "docs/product/capability_registry.yml" ])

    assert_not source.same_tree?
    assert_predicate source, :valid?
    assert_empty source.unexpected
  end

  test "動くものが変わっていれば止める" do
    source = ReleaseSource.new(tested: "abc1234", released: "def5678",
                               changed_paths: [ "VERSION", "app/models/user.rb" ])

    assert_not source.valid?
    assert_equal [ "app/models/user.rb" ], source.unexpected
    assert_match(/app\/models\/user\.rb/, source.problems.first)
  end

  test "確かめるものが変わっていれば止める" do
    source = ReleaseSource.new(tested: "abc1234", released: "def5678",
                               changed_paths: [ "test/configuration/completion_registry_test.rb" ])

    assert_not source.valid?,
               "テストが変わった木は、そのテストを通していない"
    assert_equal [ "test/configuration/completion_registry_test.rb" ], source.unexpected
  end

  test "組み立ての入力が変わっていれば止める" do
    [ "Gemfile.lock", "Dockerfile.production", "compose.production.yaml",
      "bin/docker-entrypoint", "config/routes.rb", "db/schema.rb",
      ".github/workflows/verify.yml", "script/check_release_source" ].each do |path|
      source = ReleaseSource.new(tested: "abc1234", released: "def5678", changed_paths: [ path ])

      assert_not source.valid?, "#{path} の変更を通してしまう"
    end
  end

  test "許す道と、名前が似ているだけの道を区別する" do
    source = ReleaseSource.new(tested: "abc1234", released: "def5678",
                               changed_paths: [ "docs_generator.rb", "VERSION.rb", "README.md.bak" ])

    assert_equal [ "README.md.bak", "VERSION.rb", "docs_generator.rb" ], source.unexpected.sort
  end

  test "変わったものを一つ残らず挙げる" do
    source = ReleaseSource.new(tested: "abc1234", released: "def5678",
                               changed_paths: [ "docs/x.md", "app/a.rb", "lib/b.rb", "VERSION" ])

    assert_equal [ "app/a.rb", "lib/b.rb" ], source.unexpected.sort
  end

  test "commit を指していなければ止める" do
    assert_not ReleaseSource.new(tested: "", released: "def5678").valid?
    assert_not ReleaseSource.new(tested: "abc1234", released: "").valid?
  end
end
