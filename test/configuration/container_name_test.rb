require "test_helper"

# コンテナとイメージの名前の決め方を固定する。
#
# `docker ps` と `docker images` は、この構成を動かす者が最初に読む画面である。
# 同じ内容のものが複数行に分かれ、名前に同じ語が 2 度現れる状態は、
# 読む側へ「どちらを見ればよいか」という判断を毎回要求する。
#
# 版の決め方は test/configuration/runtime_version_test.rb が扱う。
class ContainerNameTest < ActiveSupport::TestCase
  DEVELOPMENT = YAML.safe_load_file(Rails.root.join("compose.yaml"), aliases: true).freeze
  PRODUCTION = YAML.safe_load_file(Rails.root.join("compose.production.yaml"), aliases: true).freeze

  # 画面を出す側と、ジョブを実行する側。同じコードを同じ依存で動かす。
  APPLICATION_SERVICES = %w[web worker].freeze

  test "開発用の web と worker が同じイメージで動く" do
    # 別々に組み立てると、同じ内容のイメージが 2 つでき、組み立ても 2 回走る。
    images = application_images(DEVELOPMENT)

    assert_not_includes images.values, nil, "イメージ名を持たない service がある: #{images.inspect}"
    assert_equal 1, images.values.uniq.size, "イメージが分かれている: #{images.inspect}"
  end

  test "配布用の web と worker が同じイメージで動く" do
    images = application_images(PRODUCTION)

    assert_not_includes images.values, nil, "イメージ名を持たない service がある: #{images.inspect}"
    assert_equal 1, images.values.uniq.size, "イメージが分かれている: #{images.inspect}"
  end

  test "開発用のイメージ名は project 名から決まる" do
    # 継続的インテグレーションは、同じホストで並行しても互いのコンテナと
    # ボリュームを掴まないよう project 名を分けている。イメージ名だけを固定に
    # すると、その分離がイメージには効かず、別の commit の内容で起動し得る。
    assert_equal [ "${COMPOSE_PROJECT_NAME}:development" ], application_images(DEVELOPMENT).values.uniq
  end

  test "開発用のネットワーク名は project 名をそのまま使う" do
    # 名前を与えないと officeweave_default になる。ネットワークは 1 つしか無く、
    # default であることを名前から読み取る必要がない。
    #
    # イメージと同じく project 名から作る。書き写すと、project 名を変えたときに
    # 片方だけが古いまま残る。
    assert_equal "${COMPOSE_PROJECT_NAME}", DEVELOPMENT.dig("networks", "default", "name")
  end

  test "配布用のイメージ名は製品の技術識別子を使う" do
    # 配布先では 1 つの project しか動かない。project 名から作る理由が無い。
    assert_equal [ "officeweave:production" ], application_images(PRODUCTION).values.uniq
  end

  test "開発用の名前に同じ語が 2 度現れない" do
    # ボリュームの実際の名前は `<project 名>_<キー>` になる。
    # project 名にある語をキーへ書き足すと、一覧にはその語が 2 度並ぶ。
    names = [ DEVELOPMENT.fetch("name") ] + volume_names(DEVELOPMENT)

    repeated = names.to_h { |name| [ name, repeated_words(name) ] }.reject { |_, words| words.empty? }

    assert_empty repeated
  end

  # 配布用は対象にしない。名前を変えると、既に運用しているデータボリュームが
  # 参照されなくなり、入れ替えの時点で内容を失う。読みやすさのために払う
  # 代償ではない。開発用は作り直せるため、こちらだけを短くする。
  test "開発用と配布用でデータボリュームの名前が重ならない" do
    assert_empty volume_names(DEVELOPMENT) & volume_names(PRODUCTION)
  end

  private
    def application_images(document)
      APPLICATION_SERVICES.to_h { |name| [ name, document.dig("services", name, "image") ] }
    end

    def volume_names(document)
      document.fetch("volumes").keys.map { |key| "#{document.fetch("name")}_#{key}" }
    end

    def repeated_words(name)
      name.split(/[_-]/).tally.select { |_, count| count > 1 }.keys
    end
end
