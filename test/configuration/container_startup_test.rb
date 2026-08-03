require "test_helper"

# 起動の待ち方を固定する。
#
# `docker compose up` が終わるまでの時間は、準備が終わった時点ではなく、
# 次に確認する時点で決まる。確認の間隔が粗いと、準備できているのに待つ。
#
# 常時の間隔は粗くてよい。稼働中の判定であり、1 秒ごとに問い合わせる理由が無い。
# 起動のときだけ細かく見る。
class ContainerStartupTest < ActiveSupport::TestCase
  COMPOSE_FILES = {
    "compose.yaml" => YAML.safe_load_file(Rails.root.join("compose.yaml"), aliases: true),
    "compose.production.yaml" =>
      YAML.safe_load_file(Rails.root.join("compose.production.yaml"), aliases: true)
  }.freeze

  INSTALLATION = Rails.root.join("docs/operations/installation.md").freeze

  test "すべての service が起動中の確認間隔を持つ" do
    missing = healthchecks.reject { |_, healthcheck| healthcheck["start_interval"] }.keys

    assert_empty missing, "起動中の確認間隔がない: #{missing.join(', ')}"
  end

  test "起動中の確認間隔が常時の間隔より短い" do
    # 同じ値なら指定する意味が無い。長ければ、起動のほうが遅く気付くことになる。
    too_coarse = healthchecks.reject do |_, healthcheck|
      start_interval = healthcheck["start_interval"]

      start_interval && seconds(start_interval) < seconds(healthcheck["interval"])
    end

    assert_empty too_coarse.keys, "起動中のほうが粗い: #{too_coarse.keys.join(', ')}"
  end

  test "すべての service が起動の猶予を持つ" do
    # 起動中の確認間隔は、この猶予のあいだだけ使われる。
    # 猶予が無いと、指定しても使われない。
    missing = healthchecks.reject { |_, healthcheck| healthcheck["start_period"] }.keys

    assert_empty missing, "起動の猶予がない: #{missing.join(', ')}"
  end

  test "導入手順が必要な Docker の版を示す" do
    # 起動中の確認間隔は Docker Engine 25.0 と Compose v2.24 で入った。
    # 示さないと、古い環境では構成の読み取りで止まる。
    assert_match(/Docker Engine 25\.0/, INSTALLATION.read)
    assert_match(/Docker Compose v2\.24/, INSTALLATION.read)
  end

  private
    # `<ファイル名> の <service 名>` を鍵にした healthcheck の一覧。
    def healthchecks
      COMPOSE_FILES.flat_map { |path, document|
        document.fetch("services").filter_map do |name, service|
          [ "#{path} の #{name}", service["healthcheck"] ] if service["healthcheck"]
        end
      }.to_h
    end

    def seconds(duration)
      duration.to_s[/\A(\d+)s\z/, 1]&.to_i or raise "秒で指定していない: #{duration.inspect}"
    end
end
