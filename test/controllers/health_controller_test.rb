require "test_helper"

class HealthControllerTest < ActionDispatch::IntegrationTest
  test "依存先が正常なら ok を返す" do
    get health_url

    assert_response :success

    body = response.parsed_body
    assert_equal "ok", body["status"]
    assert_equal "ok", body.dig("checks", "database")
    assert body["checked_at"].present?
  end

  test "データベースへ到達できない場合は 503 を返す" do
    # 接続そのものを差し替えると、テストを包むトランザクションが失われる。
    # 問い合わせだけを失敗させて、稼働確認の応答を確認する。
    connection = ActiveRecord::Base.connection
    connection.define_singleton_method(:select_value) do |*|
      raise ActiveRecord::ConnectionNotEstablished
    end

    get health_url

    assert_response :service_unavailable

    body = response.parsed_body
    assert_equal "error", body["status"]
    assert_equal "error", body.dig("checks", "database")
  ensure
    connection&.singleton_class&.remove_method(:select_value)
  end
end
