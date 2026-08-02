require "test_helper"

# 検索の対象。
#
# 検索は文書と利用者だけが持っていた。お知らせと申請は、件数が増えると
# 一覧を辿るしかない。同じ書き方（部分一致）でそろえる。
class SearchScopeTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:main)
  end

  test "お知らせを題名で引ける" do
    target = create_announcement(title: "年末年始の休業", body: "本文")
    create_announcement(title: "別の知らせ", body: "本文")

    assert_equal [ target ], @organization.announcements.search("年末").to_a
  end

  test "お知らせを本文で引ける" do
    target = create_announcement(title: "知らせ", body: "健康診断の日程")

    assert_includes @organization.announcements.search("健康診断"), target
  end

  test "申請を題名で引ける" do
    assert_includes @organization.requests.search(requests(:taro_leave_pending).title[0, 3]),
                    requests(:taro_leave_pending)
  end

  test "申請を本文で引ける" do
    target = @organization.requests.create!(request_type: request_types(:leave), applicant: users(:taro),
                                            title: "申請", body: "私用のため")

    assert_includes @organization.requests.search("私用"), target
  end

  test "指定が無ければ全件を返す" do
    [ nil, "", "  " ].each do |query|
      assert_equal @organization.announcements.count, @organization.announcements.search(query).count,
                   query.inspect
      assert_equal @organization.requests.count, @organization.requests.search(query).count, query.inspect
    end
  end

  test "検索の記号は文字として扱う" do
    assert_empty @organization.announcements.search("%")
    assert_empty @organization.requests.search("%")
  end

  test "文書は添付の名前でも引ける" do
    document = @organization.documents.create!(author: users(:taro), title: "手順", body: "本文")
    document.attachments.attach(io: StringIO.new("中身"), filename: "安全手順書.txt",
                                content_type: "text/plain")

    assert_includes Document.search("安全手順書"), document
  end

  test "添付の名前で引いても、同じ文書は 1 件だけ返る" do
    document = @organization.documents.create!(author: users(:taro), title: "手順", body: "本文")
    2.times do |index|
      document.attachments.attach(io: StringIO.new("中身"), filename: "共通の名前#{index}.txt",
                                  content_type: "text/plain")
    end

    assert_equal 1, Document.search("共通の名前").where(id: document.id).count
  end

  test "検索の対象は参照できる記録に限る" do
    # 検索は絞り込みであり、参照できる範囲を広げない。
    hidden = create_announcement(title: "営業部だけの知らせ", body: "本文", visibility: "departments",
                                 departments: [ departments(:sales) ])

    refute_includes Announcement.visible_to(users(:outsider_free)).search("営業部だけ"), hidden
  end

  private
    def create_announcement(title:, body:, visibility: "organization", departments: [])
      @organization.announcements.create!(author: users(:taro), title: title, body: body,
                                         visibility: visibility, departments: departments,
                                         published_at: Time.current)
    end
end
