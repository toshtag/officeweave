require "test_helper"

# API トークンの許可する範囲。
#
# token の権限は、発行した利用者から引き継ぐ。範囲はそれを狭めるだけで、
# 広げない。広げられると、利用者の権限を変えても接続だけが残る。
#
# 既に発行した token の使える範囲は狭めない。範囲を持たない token は、
# これまでどおりすべての資源を読める。
class ApiTokenScopeTest < ActiveSupport::TestCase
  setup do
    @user = users(:taro)
  end

  test "扱う範囲は API の資源に対応する" do
    assert_equal %w[announcements events departments users], ApiToken::SCOPES
  end

  test "範囲を指定しなければ、すべての資源を許す" do
    token = issue(scopes: nil)

    assert_nil token.scopes
    ApiToken::SCOPES.each { |scope| assert token.permits?(scope), scope }
  end

  test "指定した範囲だけを許す" do
    token = issue(scopes: %w[announcements events])

    assert token.permits?("announcements")
    assert token.permits?("events")
    refute token.permits?("departments")
    refute token.permits?("users")
  end

  test "知らない範囲は受け付けない" do
    token = @user.api_tokens.new(organization: @user.organization, name: "誤り", scopes: %w[everything])

    assert_not token.valid?
    assert_includes token.errors.attribute_names, :scopes
  end

  test "空の指定は受け付けない" do
    # 何も読めない token は、発行した時点で用途が無い。
    token = @user.api_tokens.new(organization: @user.organization, name: "空", scopes: [])

    assert_not token.valid?
    assert_includes token.errors.attribute_names, :scopes
  end

  test "重複と空欄を取り除いて保つ" do
    token = issue(scopes: [ "events", "events", "", nil ])

    assert_equal %w[events], token.scopes
  end

  test "並びは決めた順にそろえる" do
    # 選んだ順で保つと、同じ範囲の token が別の値として残る。
    token = issue(scopes: %w[users announcements])

    assert_equal %w[announcements users], token.scopes
  end

  test "範囲は利用者の権限を広げない" do
    # 一般利用者の token へ利用者の一覧を許しても、管理者の判定は変わらない。
    member = users(:hanako)
    token = member.api_tokens.create!(organization: member.organization, name: "広げない",
                                      scopes: %w[users])

    assert token.permits?("users")
    refute_predicate token.user, :administrator?
  end

  private
    def issue(scopes:)
      @user.api_tokens.create!(organization: @user.organization, name: "検証用", scopes: scopes)
    end
end
