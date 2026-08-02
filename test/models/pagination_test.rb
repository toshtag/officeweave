require "test_helper"

# 一覧のページ送り。
#
# 蓄積する一覧は、件数が増えると開けなくなる。1 ページ分だけを読み、
# 前後へ移れるようにする。
#
# 総数は 1 回だけ数える。ページの組み立てと表示の両方で数えると、
# 同じ問い合わせが 2 度出る。
class PaginationTest < ActiveSupport::TestCase
  setup do
    @scope = User.where(organization: organizations(:main)).order(:id)
    @total = @scope.count
  end

  test "指定したページ分だけを読む" do
    page = paginate(page: 1, per_page: 2)

    assert_equal 2, page.records.size
    assert_equal @scope.limit(2).to_a, page.records
  end

  test "次のページへ進める" do
    first = paginate(page: 1, per_page: 2)
    second = paginate(page: 2, per_page: 2)

    assert_predicate first, :next_page?
    assert_equal 2, second.current_page
    refute_equal first.records, second.records
  end

  test "最後のページでは次へ進めない" do
    last = paginate(page: (@total / 2.0).ceil, per_page: 2)

    refute_predicate last, :next_page?
  end

  test "最初のページでは前へ戻れない" do
    first = paginate(page: 1, per_page: 2)

    refute_predicate first, :previous_page?
    assert_predicate paginate(page: 2, per_page: 2), :previous_page?
  end

  test "総数とページ数を持つ" do
    page = paginate(page: 1, per_page: 2)

    assert_equal @total, page.total_count
    assert_equal (@total / 2.0).ceil, page.total_pages
  end

  test "総数は 1 回だけ数える" do
    page = paginate(page: 1, per_page: 2)
    page.total_count

    counted = count_queries do
      page.total_count
      page.total_pages
      page.next_page?
      page.paginated?
    end

    assert_equal 0, counted, "総数を数え直している"
  end

  test "1 ページに収まる場合はページ送りを出さない" do
    page = paginate(page: 1, per_page: @total + 1)

    refute_predicate page, :paginated?
  end

  test "収まらない場合はページ送りを出す" do
    assert_predicate paginate(page: 1, per_page: 1), :paginated?
  end

  test "範囲の外のページは最初のページとして扱う" do
    [ 0, -3, nil, "", "abc" ].each do |value|
      assert_equal 1, paginate(page: value, per_page: 2).current_page, value.inspect
    end
  end

  test "最後のページより後を指定しても記録を返す" do
    # 蓄積した一覧では、開いたあとに件数が減ることがある。
    page = paginate(page: @total + 10, per_page: 2)

    assert_equal @total, page.total_count
    assert_empty page.records
    assert_predicate page, :previous_page?
  end

  test "1 ページの件数は上限を超えない" do
    page = paginate(page: 1, per_page: Pagination::MAXIMUM_PER_PAGE + 50)

    assert_equal Pagination::MAXIMUM_PER_PAGE, page.per_page
  end

  test "記録が無い場合も扱える" do
    page = Pagination.new(User.none, page: 1, per_page: 10)

    assert_empty page.records
    assert_equal 0, page.total_count
    assert_equal 1, page.total_pages
    refute_predicate page, :paginated?
  end

  private
    def paginate(page:, per_page:)
      Pagination.new(@scope, page: page, per_page: per_page)
    end

    def count_queries
      count = 0
      subscription = ActiveSupport::Notifications.subscribe("sql.active_record") do |_, _, _, _, payload|
        count += 1 unless payload[:name].to_s.in?([ "SCHEMA", "TRANSACTION" ])
      end
      yield
      count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscription)
    end
end
