require "test_helper"

# 範囲の一覧と、API の資源の対応。
#
# 範囲の判定は制御部の名前で行う（Api::BaseController#authorize_scope）。
# 資源を足したのに一覧へ足さないと、その資源はどの token でも読めない。
# 一覧へ足したのに資源が無ければ、選べる範囲だけが増える。
#
# どちらも画面やテストからは見えにくい。ここで対応そのものを固定する。
class ApiScopeCoverageTest < ActiveSupport::TestCase
  # 一覧に無い名前は、認証を通ったあとで 403 になる。逆に、資源の無い名前を
  # 一覧へ足すと、選べる範囲だけが増える。
  test "範囲の一覧が API の資源と 1 対 1 で対応する" do
    assert_equal ApiToken::SCOPES.sort, api_resources.sort
  end

  test "範囲の判定は、持っている範囲だけを許す" do
    token = ApiToken.new(scopes: %w[announcements])

    assert token.permits?("announcements")
    refute token.permits?("events")
    # 一覧そのものに無い名前も、当然許さない。
    refute token.permits?("reservations")
  end

  private
    # Api::V1 の制御部の名前。範囲の判定はこの名前で行う。
    def api_resources
      Rails.root.glob("app/controllers/api/v1/*_controller.rb").map do |path|
        path.basename(".rb").to_s.delete_suffix("_controller")
      end
    end
end
