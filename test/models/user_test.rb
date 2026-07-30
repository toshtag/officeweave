require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup { @organization = organizations(:main) }

  test "氏名とメールアドレスとパスワードがあれば作成できる" do
    user = build_user

    assert user.valid?
  end

  test "氏名がないと作成できない" do
    user = build_user(name: nil)

    assert_not user.valid?
    assert_predicate user.errors[:name], :present?
  end

  test "メールアドレスは大文字と前後の空白を正規化して保存する" do
    user = build_user(email_address: "  Ichiro@Example.COM ")
    user.save!

    assert_equal "ichiro@example.com", user.email_address
  end

  test "同じメールアドレスは登録できない" do
    user = build_user(email_address: users(:taro).email_address.upcase)

    assert_raises(ActiveRecord::RecordNotUnique) { user.save(validate: false) }
  end

  test "形式が正しくないメールアドレスは登録できない" do
    user = build_user(email_address: "not-an-email")

    assert_not user.valid?
  end

  test "対応していない表示言語は設定できない" do
    user = users(:taro)
    user.locale = "fr"

    assert_not user.valid?
  end

  test "表示言語は未設定にできる" do
    user = users(:taro)
    user.locale = nil

    assert user.valid?
  end

  test "主たる所属を取り出せる" do
    assert_equal departments(:sales), users(:taro).primary_department
  end

  test "主たる所属がない場合は nil を返す" do
    assert_nil users(:hanako).primary_department
  end

  test "最後の利用中の管理者を一般利用者へ変更できない" do
    administrator = users(:taro)

    assert_not administrator.update(role: "member")
    assert_includes administrator.errors.details[:base], { error: :last_active_administrator }
    assert_equal "administrator", administrator.reload.role
    assert_equal 1, active_administrator_count
  end

  test "最後の利用中の管理者を無効化できない" do
    administrator = users(:taro)
    administrator.sessions.create!

    assert_raises(ActiveRecord::RecordNotSaved) { administrator.deactivate! }

    assert_predicate administrator.reload, :active?
    assert_predicate administrator, :administrator?
    assert_equal 1, administrator.sessions.count
    assert_equal 1, active_administrator_count
  end

  test "管理者が 2 人いれば一般利用者へ変更できる" do
    users(:hanako).update!(role: "administrator")

    assert users(:taro).update(role: "member")
    assert_predicate users(:hanako).reload, :administrator?
    assert_equal 1, active_administrator_count
  end

  test "管理者が 2 人いれば無効化できる" do
    users(:hanako).update!(role: "administrator")
    users(:taro).sessions.create!

    users(:taro).deactivate!

    assert_not_predicate users(:taro).reload, :active?
    assert_empty users(:taro).sessions
    assert_equal 1, active_administrator_count
  end

  test "無効にした管理者は人数に数えない" do
    build_user(email_address: "deactivated@example.com", role: "administrator",
               deactivated_at: Time.current).save!

    assert_not users(:taro).update(role: "member")
    assert_equal "administrator", users(:taro).reload.role
  end

  test "別組織の管理者は人数に数えない" do
    users(:outsider).update!(role: "administrator")

    assert_not users(:taro).update(role: "member")
    assert_equal "administrator", users(:taro).reload.role
  end

  test "最後の管理者でも権限と有効状態を変えない更新はできる" do
    administrator = users(:taro)

    assert administrator.update(name: "山田 太郎（更新）")
    assert administrator.update(email_address: "taro-new@example.com")
    assert administrator.update(locale: "en")
    assert administrator.update(password: "a-new-secret-value", password_confirmation: "a-new-secret-value")
    assert_predicate administrator.reload, :administrator?
  end

  private
    def active_administrator_count
      @organization.users.active.administrator.count
    end

    def build_user(**attributes)
      @organization.users.new(
        {
          name: "鈴木 一郎",
          email_address: "ichiro@example.com",
          password: "a-secret-value"
        }.merge(attributes)
      )
    end
end
