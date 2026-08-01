require "test_helper"

class UserTest < ActiveSupport::TestCase
  include QueryCountTestHelper

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

  # 一覧は行ごとに主たる所属を表示する。先読みできない形にすると、
  # 利用者の人数だけ問い合わせが増える。
  test "主たる所属は先読みできる" do
    users = User.where(organization_id: organizations(:main).id).includes(:primary_department).to_a

    assert_equal 0, count_queries { users.each { |user| user.primary_department&.name } }
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
    token = issue_api_token(administrator)

    assert_raises(ActiveRecord::RecordNotSaved) { administrator.deactivate! }

    assert_predicate administrator.reload, :active?
    assert_predicate administrator, :administrator?
    assert_equal 1, administrator.sessions.count
    assert_not_predicate token.reload, :revoked?
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

  test "無効にすると発行済みの token をすべて失効する" do
    user = users(:hanako)
    tokens = [ issue_api_token(user), issue_api_token(user) ]

    user.deactivate!

    assert tokens.all? { |token| token.reload.revoked? }
    assert_empty user.api_tokens.active
  end

  # 無効にした時刻と失効の時刻がずれていると、記録からは
  # 無効化とは別の失効が起きたようにしか見えない。
  test "無効にした時刻と token を失効した時刻をそろえる" do
    user = users(:hanako)
    token = issue_api_token(user)

    user.deactivate!

    assert_equal user.reload.deactivated_at, token.reload.revoked_at
  end

  test "すでに失効している token の時刻は書き換えない" do
    user = users(:hanako)
    token = issue_api_token(user)
    token.revoke!
    revoked_at = token.reload.revoked_at

    travel 1.minute
    user.deactivate!

    assert_equal revoked_at, token.reload.revoked_at
  end

  # 失効は取り消せない。再び有効にするのは利用者であって、token ではない。
  test "再び有効にしても失効した token は戻らない" do
    user = users(:hanako)
    token = issue_api_token(user)

    user.deactivate!
    user.activate!

    assert_predicate user.reload, :active?
    assert_predicate token.reload, :revoked?
    assert_empty user.api_tokens.active
  end

  test "token の失効に失敗すると無効化もセッションの削除も巻き戻す" do
    user = users(:hanako)
    user.sessions.create!
    token = issue_api_token(user)
    user.define_singleton_method(:revoke_api_tokens) { |at:| raise ActiveRecord::StatementInvalid, "失効に失敗" }

    assert_raises(ActiveRecord::StatementInvalid) { user.deactivate! }

    assert_predicate user.reload, :active?
    assert_equal 1, user.sessions.count
    assert_not_predicate token.reload, :revoked?
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

  test "1 文字のパスワードでは作成できない" do
    user = build_user(password: "a", password_confirmation: "a")

    assert_not user.valid?
    assert_includes user.errors.details[:password], { error: :too_short, count: 15 }
  end

  test "14 文字のパスワードでは作成できない" do
    user = build_user(password: "abcdefghijklmn", password_confirmation: "abcdefghijklmn")

    assert_not user.valid?
    assert_includes user.errors.details[:password], { error: :too_short, count: 15 }
  end

  # 文字種の混在は求めない。長さだけを条件とする。
  test "15 文字あれば小文字だけのパスワードでも作成できる" do
    user = build_user(password: "abcdefghijklmno", password_confirmation: "abcdefghijklmno")

    assert user.valid?
  end

  test "最低長はバイト数ではなく文字数で数える" do
    short = build_user(password: "あいうえおかきくけこさしすせ", password_confirmation: "あいうえおかきくけこさしすせ")

    assert_not short.valid?
    assert_includes short.errors.details[:password], { error: :too_short, count: 15 }

    long = build_user(password: "あいうえおかきくけこさしすせそ", password_confirmation: "あいうえおかきくけこさしすせそ")

    assert long.valid?
  end

  # 前後の空白や大文字小文字の違いで、既知の値を迂回できないようにする。
  test "既知の初期値はそのままでも表記を変えても使えない" do
    [ "change_me", "PASSWORD", " officeweave " ].each do |value|
      user = build_user(password: value, password_confirmation: value)

      assert_not user.valid?, "#{value.inspect} が受理された"
      assert_includes user.errors.details[:password], { error: :known_unsafe }
      assert_not_includes user.errors.details[:password].map { |detail| detail[:error] }, :too_short
    end
  end

  # 長さだけを見ると通ってしまう値。digest は作られるため、必須検査でも止まらない。
  test "空白だけのパスワードは長さを満たしていても使えない" do
    [ " " * 15, "\t" * 15, "　" * 15 ].each do |value|
      user = build_user(password: value, password_confirmation: value)

      assert_not user.valid?, "#{value.inspect} が受理された"
      assert_includes user.errors.details[:password], { error: :blank }
      assert_not_includes user.errors.details[:password].map { |detail| detail[:error] }, :too_short
      assert_not_includes user.errors.details[:password].map { |detail| detail[:error] }, :known_unsafe
    end
  end

  test "空白を含むだけのパスワードは使える" do
    value = "a long secret value"
    user = build_user(password: value, password_confirmation: value)

    assert user.valid?
  end

  # 前後の空白を無視する範囲が空白だけの判定と食い違うと、そこから迂回できる。
  test "既知の初期値を Unicode の空白で囲んでも使えない" do
    [ "\u3000\u3000officeweave\u3000\u3000", "\u00A0\u00A0password\u00A0\u00A0\u00A0\u00A0\u00A0" ].each do |value|
      user = build_user(password: value, password_confirmation: value)

      assert_not user.valid?, "#{value.inspect} が受理された"
      assert_includes user.errors.details[:password], { error: :known_unsafe }
      assert_not_includes user.errors.details[:password].map { |detail| detail[:error] }, :too_short
      assert_not_includes user.errors.details[:password].map { |detail| detail[:error] }, :blank
    end
  end

  test "既知の初期値を部分として含むだけのパスワードは使える" do
    value = "officeweave-is-not-the-password"
    user = build_user(password: value, password_confirmation: value)

    assert user.valid?
  end

  # 要件を満たさないパスワードで既に運用している利用者を、この検査で締め出さない。
  test "保存済みの短いパスワードは無効にならない" do
    user = users(:hanako)
    user.update_columns(password_digest: BCrypt::Password.create("short"))
    user.reload

    assert user.authenticate("short")
    assert user.update(name: "佐藤 花子（更新）")
    assert user.update(locale: "en")
    assert user.update(role: "administrator")
    assert user.reload.authenticate("short")
  end

  test "保存済みの短いパスワードを改めて設定し直すことはできない" do
    user = users(:hanako)
    user.update_columns(password_digest: BCrypt::Password.create("short"))

    assert_not user.reload.update(password: "short", password_confirmation: "short")
  end

  test "パスワードを変更すると、その利用者のセッションが破棄される" do
    user = users(:hanako)
    session = user.sessions.create!

    user.update!(password: "a-new-long-secret-value", password_confirmation: "a-new-long-secret-value")

    assert_not Session.exists?(session.id)
  end

  test "パスワードを変更しても、他の利用者のセッションは残る" do
    other = users(:taro).sessions.create!

    users(:hanako).update!(password: "a-new-long-secret-value",
                           password_confirmation: "a-new-long-secret-value")

    assert Session.exists?(other.id)
  end

  test "パスワードを伴わない更新ではセッションが残る" do
    user = users(:hanako)
    session = user.sessions.create!

    user.update!(name: "佐藤 花子（更新）")
    user.update!(locale: "ja")
    user.update!(role: "administrator")

    assert Session.exists?(session.id)
  end

  test "保存に失敗した更新ではセッションが残る" do
    user = users(:hanako)
    session = user.sessions.create!

    assert_not user.update(email_address: "not-an-email",
                           password: "a-new-long-secret-value",
                           password_confirmation: "a-new-long-secret-value")

    assert Session.exists?(session.id)
  end

  # 検査を検証へ置くと、検証を省いた保存では素通りする。
  test "検証を省いた保存でもセッションは破棄される" do
    user = users(:hanako)
    session = user.sessions.create!

    user.password = "a-new-long-secret-value"
    user.save(validate: false)

    assert_not Session.exists?(session.id)
  end

  private
    def active_administrator_count
      @organization.users.active.administrator.count
    end

    def issue_api_token(user)
      @organization.api_tokens.create!(user: user, name: "連携用")
    end

    def build_user(**attributes)
      @organization.users.new(
        {
          name: "鈴木 一郎",
          email_address: "ichiro@example.com",
          password: "a-long-secret-value"
        }.merge(attributes)
      )
    end
end
