require "test_helper"

# 認証の網羅。
#
# 共通条件 1 は、参照と更新のすべての入口に必要な認証と認可があり、組織の
# 境界を越えないことを求める。認証を要さない入口には、公開する理由と
# 返してよい情報を書くことも求める。
#
# 既定は認証を要する。開く側だけが宣言する形にすると、開いた入口の数は
# 少なく保てるが、なぜ開いているのかは宣言からは読めない。理由を書かせる。
#
# 見るのは経路の一覧そのものとする。制御部の側から数えると、経路の付いて
# いない動作まで数え、経路だけあって動作の無い入口を見落とす。
class AuthenticationCoverageTest < ActiveSupport::TestCase
  # 認証を要さないことが分かっている入口。ここが増えるときは理由も増える。
  EXPECTED_OPEN = %w[
    health#show
    locales#update
    oidc_sessions#create oidc_sessions#callback
    password_resets#new password_resets#create password_resets#edit password_resets#update
    sessions#new sessions#create
  ].freeze

  test "画面の入口はすべて、認証を要するか、理由つきで開いている" do
    undeclared = screen_entries.reject { |entry| entry[:authenticated] || entry[:reason] }

    assert_empty undeclared.map { |entry| entry[:action] },
                 "認証を要さない入口には reason を書く"
  end

  test "認証を要さない入口が、想定した一覧と一致する" do
    # 増えたことに気付けるようにする。増やす判断は、この一覧を直す操作を伴う。
    open_entries = screen_entries.reject { |entry| entry[:authenticated] }.map { |entry| entry[:action] }

    assert_equal EXPECTED_OPEN.sort, open_entries.sort
  end

  test "認証を要さない理由が、返してよい情報に触れている" do
    screen_entries.reject { |entry| entry[:authenticated] }.each do |entry|
      assert_operator entry[:reason].to_s.length, :>=, 20,
                      "#{entry[:action]} の理由が短すぎる"
    end
  end

  test "組織は、認証した利用者から決める" do
    # 要求の値から引き当てると、別組織の記録へ到達できる。
    source = Rails.root.join("app/controllers/application_controller.rb").read

    assert_includes source, "Current.user&.organization"
    assert_not_includes source, "params[:organization"
  end

  test "外部からの接続も、認証を通ってから範囲を見る" do
    source = Rails.root.join("app/controllers/api/base_controller.rb").read

    assert_includes source, "before_action :authenticate_with_token"
    assert_includes source, "before_action :authorize_scope"
    # 認証が先に並ぶ。範囲の話をする前に、値が違う要求は 401 とする。
    assert_operator source.index("authenticate_with_token"), :<, source.index(":authorize_scope")
  end

  test "見ている入口が 1 つ以上ある" do
    # 抽出の条件を間違えると、1 件も見ないまま通る。
    assert_operator screen_entries.size, :>=, 50
  end

  private
    def screen_entries
      @screen_entries ||= Rails.application.routes.routes.filter_map do |route|
        controller = route.defaults[:controller]
        action = route.defaults[:action]
        next if controller.nil? || action.nil? || controller.start_with?("api/", "rails/", "active_storage")

        klass = "#{controller}_controller".camelize.safe_constantize
        next if klass.nil? || !klass.respond_to?(:unauthenticated_reason)

        reason = klass.unauthenticated_reason(action)

        { action: "#{controller}##{action}", reason: reason, authenticated: reason.nil? }
      end.uniq { |entry| entry[:action] }
    end
end
