require "test_helper"

# 導入直後の最初のひとりを用意する処理の契約を固定する。
class InitialUserTest < ActiveSupport::TestCase
  CREDENTIALS = {
    email_address: "first@example.com",
    password: "a-long-secret-value"
  }.freeze

  test "組織が無ければ作り、最初の管理者を作る" do
    result = install(organization_code: "first-organization", organization_name: "最初の組織")

    organization = Organization.find_by!(code: "first-organization")
    user = organization.users.sole

    assert_equal :created, result
    assert_equal "最初の組織", organization.name
    assert_equal "first@example.com", user.email_address
    assert_predicate user, :administrator?
  end

  # 導入単位は組織である。全体で見ると、2 つ目の組織を足したときに
  # その組織へ誰もログインできない状態になる。
  test "既に利用者がいる組織があっても、別の組織には初期管理者を作る" do
    assert_predicate organizations(:main).users, :any?

    result = install(organization_code: "second-organization", organization_name: "2 つ目の組織")

    assert_equal :created, result
    assert_equal "first@example.com", Organization.find_by!(code: "second-organization").users.sole.email_address
  end

  test "同じ組織に利用者がいる場合は作らない" do
    result = install(organization_code: organizations(:main).code,
                     organization_name: organizations(:main).name)

    assert_equal :already_present, result
  end

  test "繰り返し実行しても利用者は増えない" do
    2.times { install(organization_code: "repeat-organization", organization_name: "繰り返しの組織") }

    assert_equal 1, Organization.find_by!(code: "repeat-organization").users.count
  end

  test "資格情報が揃っていない場合は作らない" do
    [ { email_address: nil }, { password: nil }, { email_address: "", password: "" } ].each do |missing|
      result = install(organization_code: "missing-organization",
                       organization_name: "資格情報の無い組織", **missing)

      assert_equal :missing_credentials, result
    end

    assert_empty Organization.where(code: "missing-organization").flat_map(&:users)
  end

  test "表示名を省くと既定の名前を使う" do
    install(organization_code: "unnamed-organization", organization_name: "表示名の無い組織", name: nil)

    assert_equal InitialUser::DEFAULT_NAME,
                 Organization.find_by!(code: "unnamed-organization").users.sole.name
  end

  # 空欄は Compose が未設定の変数を渡す形である。資格情報とは違い、
  # 推測して困る値ではない。
  test "表示名が空欄でも既定の名前を使う" do
    install(organization_code: "blank-organization", organization_name: "表示名が空欄の組織", name: " ")

    assert_equal InitialUser::DEFAULT_NAME,
                 Organization.find_by!(code: "blank-organization").users.sole.name
  end

  # 最低要件を満たさない値は、模型の検証が拒む。
  test "要件を満たさないパスワードでは失敗する" do
    assert_raises(ActiveRecord::RecordInvalid) do
      install(organization_code: "weak-organization", organization_name: "弱い資格情報の組織",
              password: "short")
    end
  end

  private
    def install(**attributes)
      InitialUser.install(**CREDENTIALS.merge(attributes))
    end
end
