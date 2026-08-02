require "test_helper"

# 添付ファイルの経路を固定する。
#
# 保存基盤が用意する経路は、署名付きの ID を知っている相手へそのまま配信する。
# ログインの有無も、文書の参照範囲も見ない。
# 設定を戻しても画面は動いたままなので、経路そのものを検査で押さえる。
class AttachmentRoutesTest < ActiveSupport::TestCase
  # 保存基盤が作る経路の名前。
  # 名前が残っていれば、どこかで URL を組み立てられる状態が残っている。
  STANDARD_ROUTE_NAMES = %w[
    rails_service_blob
    rails_service_blob_proxy
    rails_blob_representation
    rails_blob_representation_proxy
    rails_disk_service
    update_rails_disk_service
    rails_direct_uploads
  ].freeze

  test "保存基盤の経路を作らない設定である" do
    assert_equal false, Rails.application.config.active_storage.draw_routes
  end

  test "保存基盤の制御部へ向かう経路がない" do
    controllers = Rails.application.routes.routes.filter_map { |route| route.defaults[:controller] }

    assert_empty controllers.grep(%r{\Aactive_storage/}), "保存基盤の制御部へ到達できる"
  end

  test "/rails/active_storage で始まる経路がない" do
    paths = Rails.application.routes.routes.map { |route| route.path.spec.to_s }

    assert_empty paths.grep(%r{\A/rails/active_storage}), "保存基盤の経路が残っている"
  end

  test "保存基盤の URL を組み立てる補助メソッドがない" do
    names = Rails.application.routes.named_routes.names.map(&:to_s)

    STANDARD_ROUTE_NAMES.each do |name|
      assert_not_includes names, name
    end
  end

  test "添付は文書の配下の経路から取得する" do
    assert_equal "/documents/1/attachments/2",
                 Rails.application.routes.url_helpers.document_attachment_path(1, 2)
  end
end
