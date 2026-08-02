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

  test "ジョブの保存先と保存領域も確かめる" do
    # ジョブを積めない、添付を保存できないは、画面が開けても機能が壊れている。
    get health_url

    body = response.parsed_body

    assert_equal "ok", body.dig("checks", "queue")
    assert_equal "ok", body.dig("checks", "storage")
  end

  test "保存領域を作れない場合は 503 を返す" do
    # 経路の途中がファイルであれば、保存先のディレクトリは作れない。
    service = ActiveStorage::Blob.service
    blocked = Rails.root.join("Gemfile/storage").to_s
    service.define_singleton_method(:root) { blocked }

    get health_url

    assert_response :service_unavailable
    assert_equal "error", response.parsed_body.dig("checks", "storage")
  ensure
    service&.singleton_class&.remove_method(:root)
  end

  test "保存先がまだ作られていなくても、作れるなら ok とする" do
    # 保存先は最初の保存で作られる。1 度も保存していない環境で、
    # 稼働確認だけが失敗する状態にしない。
    service = ActiveStorage::Blob.service
    absent = Rails.root.join("tmp/storage-not-created-yet")
    FileUtils.rm_rf(absent)
    service.define_singleton_method(:root) { absent.to_s }

    get health_url

    assert_response :success
    assert_equal "ok", response.parsed_body.dig("checks", "storage")
    refute File.exist?(absent), "稼働確認が保存先を作っている"
  ensure
    service&.singleton_class&.remove_method(:root)
  end

  test "確かめる先を毎回書き込みで試さない" do
    # 稼働確認は監視から繰り返し呼ばれる。1 回ごとにファイルを作ると、
    # 監視の間隔がそのまま書き込みの回数になる。
    before = Dir.glob(File.join(ActiveStorage::Blob.service.root, "*")).size

    3.times { get health_url }

    assert_equal before, Dir.glob(File.join(ActiveStorage::Blob.service.root, "*")).size
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
