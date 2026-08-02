require "test_helper"

# 検索を画面の側から確かめる。
class SearchScopeRequestTest < ActionDispatch::IntegrationTest
  test "お知らせを検索できる" do
    target = organizations(:main).announcements.create!(author: users(:taro), title: "健康診断の案内",
                                                      body: "本文", published_at: Time.current)
    sign_in_as users(:taro)

    get announcements_url(query: "健康診断")

    assert_response :success
    assert_select "h2", text: /#{target.title}/
    assert_select "h2", { text: /#{announcements(:company_wide).title}/, count: 0 }
  end

  test "お知らせの検索の入力欄が出る" do
    sign_in_as users(:taro)

    get announcements_url

    assert_select "input[name=query]"
  end

  test "申請を検索できる" do
    sign_in_as users(:taro)
    target = requests(:taro_leave_pending)

    get requests_url(query: target.title)

    assert_select "td", text: /#{target.title}/
    assert_select "td", { text: /#{requests(:hanako_expense_pending).title}/, count: 0 }
  end

  test "申請の検索はページ送りへ引き継がれる" do
    30.times do |index|
      organizations(:main).requests.create!(request_type: request_types(:leave), applicant: users(:taro),
                                            title: "検索対象 #{index}")
    end
    sign_in_as users(:taro)

    get requests_url(query: "検索対象")

    assert_select "a[href=?]", requests_path(page: 2, query: "検索対象")
  end

  test "文書を添付の名前で検索できる" do
    document = organizations(:main).documents.create!(author: users(:taro), title: "手順", body: "本文")
    document.attachments.attach(io: StringIO.new("中身"), filename: "作業手順書.txt",
                                content_type: "text/plain")
    sign_in_as users(:taro)

    get documents_url(query: "作業手順書")

    assert_select "td", text: /#{document.title}/
  end
end
