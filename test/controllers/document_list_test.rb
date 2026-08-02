require "test_helper"

# 文書の一覧が読み込むもの。
#
# 一覧に並ぶのは件名、分類、作成者、更新日時だけである。本文は 1 件あたり
# 最大 100,000 文字あり、添付は 1 件あたり最大 10 件ある。どちらも一覧では
# 表示しない。読んだ分は、そのまま要求ごとの転送量と占有するメモリになる。
class DocumentListTest < ActionDispatch::IntegrationTest
  include QueryCountTestHelper

  setup { sign_in_as users(:taro) }

  test "一覧の取得が本文を返さない" do
    create_document("本文の大きい文書", body: "あ" * 1_000)

    documents = capture_queries { get documents_url }
                .select { |query| query[:sql].include?('FROM "documents"') }

    assert_not_empty documents
    documents.each do |query|
      assert_no_match(/"documents"\.\*/, query[:sql],
                      "一覧の取得が全列を返している")
    end
  end

  # 検索は本文を条件に使う。条件として使うことと、結果として返すことは別である。
  test "本文で検索した場合も、一覧の取得が本文を返さない" do
    create_document("検索で見つかる文書", body: "取り決めの詳細")

    documents = capture_queries { get documents_url(query: "取り決め") }
                .select { |query| query[:sql].include?('FROM "documents"') }

    assert_not_empty documents
    documents.each do |query|
      assert_no_match(/"documents"\.\*/, query[:sql],
                      "検索の一覧が全列を返している")
    end
  end

  test "本文に含まれる語で文書を探せる" do
    document = create_document("検索で見つかる文書", body: "取り決めの詳細")

    get documents_url(query: "取り決め")

    assert_select "a", text: document.title
  end

  # 添付は一覧に出さない。文書が添付を持つかどうかに関わらず、
  # 先読みは一覧の要求ごとに走る。
  test "一覧が添付を読み込まない" do
    document = create_document("添付のある文書")
    document.attachments.attach(io: StringIO.new("内容"), filename: "note.txt",
                                content_type: "text/plain")

    queries = capture_queries { get documents_url }

    assert_empty queries.select { |query| query[:sql].include?("active_storage_attachments") },
                 "一覧が添付の関連を読み込んでいる"
    assert_empty queries.select { |query| query[:sql].include?("active_storage_blobs") },
                 "一覧が添付の実体を読み込んでいる"
  end

  # 作成者と分類は一覧に出す。列を絞った結果として先読みが外れると、
  # 今度は文書の件数だけ問い合わせが増える。
  test "文書の件数が増えても問い合わせが増えない" do
    create_documents(2)
    before = count_queries { get documents_url }

    create_documents(10, offset: 2)

    assert_equal before, count_queries { get documents_url }
  end

  test "一覧に件名、分類、作成者、更新日時が並ぶ" do
    document = create_document("一覧に出る文書", category: document_categories(:rules))

    get documents_url

    assert_select "td", text: document.title
    assert_select "td", text: document.document_category.name
    assert_select "td", text: document.author.name
    assert_select "td", text: I18n.l(document.updated_at, format: :short)
  end

  test "詳細では本文と添付を表示する" do
    document = create_document("詳細を開く文書", body: "本文の中身")
    document.attachments.attach(io: StringIO.new("内容"), filename: "note.txt",
                                content_type: "text/plain")

    get document_url(document)

    assert_select "body", text: /本文の中身/
    assert_select "a", text: "note.txt"
  end

  private
    # 作成者は文書ごとに分ける。同じ利用者を指す取得は要求内のキャッシュから
    # 返るため、作成者をそろえると欠けた先読みが 1 件に見える。
    def create_documents(count, offset: 0)
      digest = BCrypt::Password.create("password-for-tests", cost: BCrypt::Engine::MIN_COST)

      count.times do |index|
        number = offset + index
        author = organizations(:main).users.create!(
          name: "作成者 #{number}", email_address: "document-author#{number}@example.com",
          password_digest: digest
        )
        create_document("一覧の文書 #{number}", author: author)
      end
    end

    def create_document(title, body: "本文", author: users(:taro), category: nil)
      organizations(:main).documents.create!(
        title: title, body: body, author: author,
        document_category: category, visibility: "organization"
      )
    end
end
