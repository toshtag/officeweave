require "test_helper"

# お知らせの一覧が出す問い合わせ。
#
# 一覧は公開済み、公開待ち、下書きの 3 区分を並べる。どの区分も作成者の
# 氏名を表示するため、先読みが欠けた区分では件数だけ問い合わせが出る。
class AnnouncementListTest < ActionDispatch::IntegrationTest
  include QueryCountTestHelper

  setup { sign_in_as users(:taro) }

  # 作成者は区分ごとに分ける。同じ利用者を指す取得は要求内のキャッシュから
  # 返るため、作成者をそろえると欠けた先読みが 1 件に見える。
  test "下書きの件数が増えても問い合わせが増えない" do
    create_announcements(2) { |author, index| draft(author, index) }
    before = count_queries { get announcements_url }

    create_announcements(10, offset: 2) { |author, index| draft(author, index) }

    assert_equal before, count_queries { get announcements_url }
  end

  test "公開待ちの件数が増えても問い合わせが増えない" do
    create_announcements(2) { |author, index| scheduled(author, index) }
    before = count_queries { get announcements_url }

    create_announcements(10, offset: 2) { |author, index| scheduled(author, index) }

    assert_equal before, count_queries { get announcements_url }
  end

  test "3 つの区分が並ぶ" do
    create_announcements(1) { |author, index| draft(author, index) }
    create_announcements(1, offset: 1) { |author, index| scheduled(author, index) }

    get announcements_url

    assert_select "h2", text: I18n.t("announcements.index.scheduled")
    assert_select "h2", text: I18n.t("announcements.index.drafts")
    assert_select "a", text: announcements(:company_wide).title
  end

  test "公開待ちは公開日時の早い順に並ぶ" do
    later = create_scheduled("後のお知らせ", at: 5.days.from_now)
    sooner = create_scheduled("先のお知らせ", at: 2.days.from_now)

    get announcements_url

    titles = css_select("h3").map(&:text)

    assert_operator titles.index(sooner.title), :<, titles.index(later.title)
  end

  test "一般の利用者には下書きと公開待ちが並ばない" do
    create_announcements(1) { |author, index| draft(author, index) }
    sign_in_as users(:hanako)

    get announcements_url

    assert_select "h2", text: I18n.t("announcements.index.drafts"), count: 0
    assert_select "h2", text: I18n.t("announcements.index.scheduled"), count: 0
  end

  private
    def create_announcements(count, offset: 0)
      digest = BCrypt::Password.create("password-for-tests", cost: BCrypt::Engine::MIN_COST)

      count.times do |index|
        position = offset + index
        author = organizations(:main).users.create!(
          name: "作成者 #{position}", email_address: "author#{position}@example.com",
          password_digest: digest
        )
        yield(author, position)
      end
    end

    def draft(author, index)
      organizations(:main).announcements.create!(
        author: author, title: "下書き #{index}", body: "本文", visibility: "organization"
      )
    end

    def scheduled(author, index)
      organizations(:main).announcements.create!(
        author: author, title: "公開待ち #{index}", body: "本文",
        visibility: "organization", published_at: (index + 1).days.from_now
      )
    end

    def create_scheduled(title, at:)
      organizations(:main).announcements.create!(
        author: users(:taro), title: title, body: "本文",
        visibility: "organization", published_at: at
      )
    end
end
