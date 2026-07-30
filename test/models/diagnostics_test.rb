require "test_helper"

class DiagnosticsTest < ActiveSupport::TestCase
  setup { @checks = Diagnostics.new.run }

  test "確認の一覧を返す" do
    assert_operator @checks.size, :>=, 8
    assert(@checks.all? { |check| check[:name].present? })
    assert(@checks.all? { |check| %i[ok warning error].include?(check[:status]) })
  end

  test "データベースへの接続を確認する" do
    check = find("データベースへの接続")

    assert_equal :ok, check[:status]
    assert_match "PostgreSQL", check[:detail]
  end

  test "必要な拡張機能を確認する" do
    check = find("データベースの拡張機能")

    assert_equal :ok, check[:status]
    assert_match "btree_gist", check[:detail]
    assert_match "pg_trgm", check[:detail]
  end

  test "移行が適用済みであることを確認する" do
    assert_equal :ok, find("データベースの移行")[:status]
  end

  test "ファイルの保存先へ書き込めることを確認する" do
    assert_equal :ok, find("ファイルの保存先")[:status]
  end

  test "添付ファイルの取得経路が文書の配下だけであることを確認する" do
    check = find("添付ファイルの取得経路")

    assert_equal :ok, check[:status]
  end

  test "有効な管理者がいない場合は失敗として扱う" do
    User.update_all(role: "member")

    assert_equal :error, Diagnostics.new.run.find { |c| c[:name] == "管理者" }[:status]
  end

  test "無効にされた管理者は数えない" do
    User.where(role: "administrator").find_each(&:deactivate!)

    assert_equal :error, Diagnostics.new.run.find { |c| c[:name] == "管理者" }[:status]
  end

  test "送信しない設定は注意として扱う" do
    check = find("メールの送信")

    assert_includes %i[warning ok], check[:status]
  end

  private
    def find(name)
      @checks.find { |check| check[:name] == name }
    end
end
