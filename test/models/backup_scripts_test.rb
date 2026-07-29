require "application_system_test_case"

# 手順が実行できる形で置かれていることを確認する。
# 個々の振る舞いは backup_script_test.rb と restore_script_test.rb で扱う。
class BackupScriptsTest < ActiveSupport::TestCase
  test "取得と復元の手順が実行できる形で置かれている" do
    %w[bin/backup bin/restore script/production_backup script/production_restore].each do |path|
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
