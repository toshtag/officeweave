require "test_helper"

# 運用環境が受け入れる Host を固定する。
#
# 実際に拒否できるかは、起動した運用環境への要求で確かめる。
# ここで押さえるのは、設定そのものが外れないことだけとする。
# 設定が外れても画面は動く。想定外のホスト名で届いた要求も通るようになるだけで、
# 通常の利用では気付けない。
class HostAuthorizationTest < ActiveSupport::TestCase
  test "運用環境は受け入れるホスト名を設定から与える" do
    assert_includes production_configuration, %(config.hosts = [ ENV.fetch("APPLICATION_HOST", "localhost") ])
  end

  test "稼働確認の経路を Host の検査から外さない" do
    refute_match(/^\s*config\.host_authorization\s*=/, production_configuration)
  end

  private
    def production_configuration
      File.read(Rails.root.join("config/environments/production.rb"))
    end
end
