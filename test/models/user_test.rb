require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "氏名とメールアドレスとパスワードがあれば作成できる" do
    user = User.new(name: "鈴木 一郎", email_address: "ichiro@example.com", password: "a-secret-value")

    assert user.valid?
  end

  test "氏名がないと作成できない" do
    user = User.new(email_address: "ichiro@example.com", password: "a-secret-value")

    assert_not user.valid?
    assert_predicate user.errors[:name], :present?
  end

  test "メールアドレスは大文字と前後の空白を正規化して保存する" do
    user = User.create!(name: "鈴木 一郎", email_address: "  Ichiro@Example.COM ", password: "a-secret-value")

    assert_equal "ichiro@example.com", user.email_address
  end

  test "同じメールアドレスは登録できない" do
    existing = users(:taro)
    user = User.new(name: "別人", email_address: existing.email_address.upcase, password: "a-secret-value")

    assert_raises(ActiveRecord::RecordNotUnique) { user.save(validate: false) }
  end

  test "形式が正しくないメールアドレスは登録できない" do
    user = User.new(name: "鈴木 一郎", email_address: "not-an-email", password: "a-secret-value")

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
end
