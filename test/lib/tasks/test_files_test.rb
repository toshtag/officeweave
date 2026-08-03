require "test_helper"
require Rails.root.join("lib/tasks/test_files").to_s

# テストを分けて走らせるときの分け方。
#
# 分けた以上、どの組にも入らないファイルが生じ得る。生じても、その場では
# 何も失敗しない。分けた組はすべて緑になり、実行されていないことに気付けない。
class TestFilesTest < ActiveSupport::TestCase
  TOTAL = 3

  setup do
    @all = Officeweave::TestFiles.all
    @shards = (1..TOTAL).map { |index| Officeweave::TestFiles.shard(index, TOTAL) }
  end

  test "分けた組を合わせると全件になる" do
    assert_equal @all.sort, @shards.flatten.sort
  end

  test "組の間で重ならない" do
    combined = @shards.flatten

    assert_equal combined.size, combined.uniq.size
  end

  # 偏ると、待ち時間は最も重い組で決まる。分け方の効果が失われる。
  test "組の大きさがそろう" do
    sizes = @shards.map(&:size)

    assert_operator sizes.max - sizes.min, :<=, 1
  end

  # ブラウザーは別の service を要する。分けた側へ紛れ込むと、
  # 追加の道具が無い環境で落ちる。
  test "実ブラウザーの層を含まない" do
    assert_empty @all.grep(%r{\Atest/browser/})
  end

  test "試験でないものを含まない" do
    assert_empty @all.grep(%r{\Atest/(dummy|fixtures)/})
  end

  # 空振りに気付けるようにする。対象が無くても、落ちないという結果は同じになる。
  test "1 件以上見つけている" do
    assert_operator @all.size, :>=, 1
  end

  test "分けずに指定した場合は全件を返す" do
    assert_equal @all, Officeweave::TestFiles.shard(1, 1)
  end

  # 誤った指定を受け付けると、どの組にも入らないファイルが黙って生まれる。
  test "数え方の誤りを受け付けない" do
    [ [ 0, 3 ], [ 4, 3 ], [ 1, 0 ], [ -1, 3 ] ].each do |index, total|
      assert_raises(ArgumentError, "#{index}/#{total} を受け付けた") do
        Officeweave::TestFiles.shard(index, total)
      end
    end
  end

  test "読めない書き方を受け付けない" do
    [ "", "1", "1/", "一/三", "1/3/5" ].each do |specification|
      assert_raises(ArgumentError, "#{specification.inspect} を受け付けた") do
        Officeweave::TestFiles.parse(specification)
      end
    end
  end

  test "1/3 の形を受け取る" do
    assert_equal Officeweave::TestFiles.shard(2, 3), Officeweave::TestFiles.parse("2/3")
  end
end
