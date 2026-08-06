require "test_helper"

# 選択欄へ並べる候補。
#
# 対象を全件描くと、描く量が組織の規模に比例する。上限を置いたうえで、
# 絞り込みで残りへ到達できるようにする。
class CandidatesTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:main)
  end

  test "上限までしか並べない" do
    create_users(5)

    assert_equal 3, Candidates.new(@organization.users.ordered, limit: 3).records.size
  end

  test "上限に達したら、残りの数を示す" do
    create_users(5)
    candidates = Candidates.new(@organization.users.ordered, limit: 2)

    assert_predicate candidates, :truncated?
    assert_operator candidates.remaining, :>, 0
  end

  test "上限に達しなければ、切り詰めたとは言わない" do
    candidates = Candidates.new(@organization.users.ordered, limit: 1_000)

    assert_not_predicate candidates, :truncated?
    assert_equal 0, candidates.remaining
  end

  test "絞り込みは模型が持つ検索へ委ねる" do
    create_users(3, prefix: "検索対象")
    candidates = Candidates.new(@organization.users.ordered, query: "検索対象")

    assert_equal 3, candidates.records.size
    assert(candidates.records.all? { |user| user.name.include?("検索対象") })
  end

  test "既に選んである候補は、絞り込んでも必ず含める" do
    # 含めないと、絞り込んだ状態で保存したときに、画面へ出ていない選択が外れる。
    selected = users(:hanako)
    candidates = Candidates.new(@organization.users.ordered, query: "該当しない語",
                                selected_ids: [ selected.id ])

    assert_includes candidates.records, selected
  end

  test "選んである候補を二重に並べない" do
    selected = users(:taro)
    candidates = Candidates.new(@organization.users.ordered, selected_ids: [ selected.id ])

    assert_equal 1, candidates.records.count { |user| user == selected }
  end

  test "組織の境界は渡された範囲が持つ" do
    # 候補そのものは絞り込みを足さない。範囲を組み立てる側が組織で絞る。
    candidates = Candidates.new(@organization.users.ordered)

    assert_not_includes candidates.records, users(:outsider)
  end

  test "検索を持たない範囲では、絞り込みを無視する" do
    scope = @organization.request_types.all
    assert_not scope.respond_to?(:search)

    assert_equal scope.count, Candidates.new(scope, query: "何か").records.size
  end

  test "空の指定は絞り込みとして扱わない" do
    total = @organization.users.count

    assert_equal total, Candidates.new(@organization.users.ordered, query: "  ").records.size
  end

  private
    def create_users(count, prefix: "候補")
      count.times do |index|
        @organization.users.create!(name: "#{prefix} #{index}",
                                    email_address: "#{prefix.hash.abs}-#{index}@example.com",
                                    password: "a-long-enough-password")
      end
    end
end
