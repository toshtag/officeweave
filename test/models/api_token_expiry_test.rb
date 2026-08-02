require "test_helper"

# API トークンの有効期限。
#
# token は発行したあと、使われ続けるかどうかに関わらず有効だった。
# 用途が終わっても失効させ忘れれば、その接続は残る。
#
# 既に発行した token の使える範囲は狭めない。期限を持たない token は、
# これまでどおり使える。この版へ入れ替えただけで外部との接続が切れると、
# 切れた理由が入れ替えと結び付かない。
class ApiTokenExpiryTest < ActiveSupport::TestCase
  setup do
    @user = users(:taro)
  end

  test "期限を指定して発行できる" do
    token = issue(expires_in_days: 30)

    assert_in_delta 30.days.from_now, token.expires_at, 1.minute
  end

  test "期限を指定しなければ持たない" do
    token = issue(expires_in_days: nil)

    assert_nil token.expires_at
  end

  test "期限を過ぎた token では認証できない" do
    token = issue(expires_in_days: 30)
    value = token.token

    travel 31.days do
      assert_nil ApiToken.authenticate(value)
    end
  end

  test "期限の内側では認証できる" do
    token = issue(expires_in_days: 30)
    value = token.token

    travel 29.days do
      assert_equal token, ApiToken.authenticate(value)
    end
  end

  test "期限の時刻ちょうどは使えない" do
    token = issue(expires_in_days: 30)
    value = token.token

    travel_to token.expires_at do
      assert_nil ApiToken.authenticate(value)
    end
  end

  test "期限を持たない token は使い続けられる" do
    token = issue(expires_in_days: nil)
    value = token.token

    travel 10.years do
      assert_equal token, ApiToken.authenticate(value)
    end
  end

  test "期限が過去の指定は受け付けない" do
    token = @user.api_tokens.new(organization: @user.organization, name: "過去", expires_at: 1.minute.ago)

    assert_not token.valid?
    assert_includes token.errors.attribute_names, :expires_at
  end

  test "期限を過ぎた token は、使えない理由を状態として示す" do
    token = issue(expires_in_days: 30)

    travel 31.days do
      assert_predicate token, :expired?
      refute_predicate token, :usable?
      # 失効とは分ける。失効は人が止めたことであり、期限は最初に決めた条件である。
      refute_predicate token, :revoked?
    end
  end

  test "使える token だけを選べる" do
    active = issue(expires_in_days: 30)
    unlimited = issue(expires_in_days: nil)
    expired = issue(expires_in_days: 1)
    revoked = issue(expires_in_days: 30).tap(&:revoke!)

    travel 2.days do
      usable = @user.api_tokens.usable

      assert_includes usable, active
      assert_includes usable, unlimited
      refute_includes usable, expired
      refute_includes usable, revoked
    end
  end

  test "期限の指定は決めた候補だけとする" do
    # 任意の日数を受け取ると、1 日や 10 年といった値が画面から入る。
    assert_equal [ 30, 90, 365 ], ApiToken::EXPIRY_CHOICES
  end

  private
    def issue(expires_in_days:)
      @user.api_tokens.create!(
        organization: @user.organization,
        name: "検証用 #{expires_in_days.inspect}",
        expires_at: expires_in_days&.days&.from_now
      )
    end
end
