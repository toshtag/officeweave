require "application_system_test_case"

# 取得と復元の手順そのものは、実行環境に依存するためここでは扱わない。
# 手順書が存在し、README から到達できることだけを確認する。
class BackupScriptsTest < ActiveSupport::TestCase
  test "取得と復元の手順が実行できる形で置かれている" do
    %w[bin/backup bin/restore].each do |path|
      full_path = Rails.root.join(path)

      assert File.exist?(full_path), "#{path} が存在しない"
      assert File.executable?(full_path), "#{path} が実行できない"
    end
  end

  test "手順書が存在する" do
    assert File.exist?(Rails.root.join("docs/operations/backup.md"))
  end

  test "書庫の置き場所は追跡対象へ含めない" do
    assert_includes File.read(Rails.root.join(".gitignore")), "backups/"
  end
end
