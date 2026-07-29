require "test_helper"

class DemoDataTest < ActiveSupport::TestCase
  test "一通りの記録が作られる" do
    counts = DemoData.new.install

    assert_equal 5, counts["部門"]
    assert_equal 5, counts["利用者"]
    assert_equal 3, counts["設備・備品"]
    assert_operator counts["お知らせ"].size, :>=, 2
  end

  test "何度実行しても同じ状態になる" do
    DemoData.new.install
    counts_after_first = record_counts

    DemoData.new.install

    assert_equal counts_after_first, record_counts
  end

  test "作られた利用者でログインできる" do
    DemoData.new.install

    user = Authentication::InternalProvider.authenticate(
      email_address: "admin@demo.invalid", password: DemoData::PASSWORD
    )

    assert_predicate user, :administrator?
  end

  test "既存の組織とは別に作られる" do
    DemoData.new.install

    assert_not_equal organizations(:main), Organization.find_by(code: "demo")
    assert_equal 5, Organization.find_by(code: "demo").users.count
  end

  test "上位部門を持つ部門が作られる" do
    DemoData.new.install

    department = Organization.find_by(code: "demo").departments.find_by(code: "sales-east")

    assert_equal "sales", department.parent.code
  end

  test "提出済みの申請が作られる" do
    DemoData.new.install

    organization = Organization.find_by(code: "demo")

    assert organization.requests.exists?(status: "pending")
    assert organization.requests.exists?(status: "draft")
  end

  test "連絡先はいずれも到達しない領域を使う" do
    DemoData::USERS.each do |user|
      assert_match(/@demo\.invalid\z/, user[:email_address])
    end
  end

  private
    def record_counts
      {
        organizations: Organization.count,
        departments: Department.count,
        users: User.count,
        announcements: Announcement.count,
        requests: Request.count,
        documents: Document.count
      }
    end
end
