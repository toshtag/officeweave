require "test_helper"

# 負荷測定用のデータ。
#
# 空のデータベースへ要求を投げても、応答の速さは分からない。一覧は並べる記録
# の数で読み込む量が変わり、検索は対象の数で走査の量が変わる。測る前に、
# 測るに足る量を積む必要がある。
#
# 実在する個人や組織の情報は使わない。すべて架空の値とする。
class LoadSampleTest < ActiveSupport::TestCase
  include IsolatedOrganizationTestHelper

  test "指定した規模で積む" do
    result = LoadSample.new(scale: 3).install

    assert_equal 3, result["利用者"]
    assert_operator result["お知らせ"], :>=, 3
    assert_operator result["文書"], :>=, 3
  end

  test "測る対象の一覧すべてに記録を積む" do
    LoadSample.new(scale: 2).install
    organization = LoadSample.organization

    assert_operator organization.announcements.count, :>, 0
    assert_operator organization.events.count, :>, 0
    assert_operator organization.reservations.count, :>, 0
    assert_operator organization.requests.count, :>, 0
    assert_operator organization.documents.count, :>, 0
    assert_operator organization.audit_events.count, :>, 0
  end

  # 測るたびに作り直す。前回の分が残ると、規模を指定した意味が無くなる。
  test "2 度実行しても規模が変わらない" do
    first = LoadSample.new(scale: 2).install
    second = LoadSample.new(scale: 2).install

    assert_equal first, second
  end

  # 既にある組織と混ざると、測っている対象が分からなくなる。
  test "専用の組織へ積む" do
    LoadSample.new(scale: 1).install

    assert_equal LoadSample::ORGANIZATION[:code], LoadSample.organization.code
    assert_not_equal organizations(:main).id, LoadSample.organization.id
  end

  # 一覧を開けるだけの権限が要る。測る対象は認証の後の画面である。
  test "測るための利用者を作る" do
    LoadSample.new(scale: 1).install
    user = LoadSample.organization.users.find_by(email_address: LoadSample::EMAIL_ADDRESS)

    assert_not_nil user
    assert_predicate user, :administrator?
    assert_predicate user, :active?
  end

  test "架空の宛先だけを使う" do
    LoadSample.new(scale: 2).install

    LoadSample.organization.users.each do |user|
      assert_match(/\.invalid\z/, user.email_address)
    end
  end
end
