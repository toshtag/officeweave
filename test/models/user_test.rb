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

  private
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
