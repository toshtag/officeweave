require "test_helper"

# 準備コマンドの契約を固定する。
#
# 開発と検証の経路は Docker Compose を正本とし、server は compose が起動する。
# 準備コマンドがそこで server を起動しようとすると、既に動いている server と
# ぶつかり、準備そのものは終わっているのに失敗として返る。
#
# 実際に走らせて確かめない。準備はデータベースと一時ファイルへ触れるため、
# 検証のたびに実行すると、動いている開発環境の側が変わる。確かめたいのは
# 手順の契約であり、準備の中身ではない。
class SetupScriptTest < ActiveSupport::TestCase
  SETUP = Rails.root.join("bin/setup").freeze

  test "準備コマンドが server を起動しない" do
    assert_no_match(/bin\/dev/, SETUP.read, "準備のあとで server を起動している")
  end

  # 起動しないことを指定するための引数が要るなら、既定が準備コマンドとして
  # 成り立っていない。
  test "準備コマンドが server を避けるための引数を持たない" do
    assert_no_match(/skip-server/, SETUP.read)
  end

  # server の場合と違い、既定が成り立っていないわけではない。既定はこれまで
  # どおりデータベースを用意する。指定を持つのは、そこへ触れない検査
  # （書式、依存の監査、静的解析）だけを走らせる経路があるためである。
  #
  # 用意すると、接続を必要としない検査にその待ち時間が乗る。
  test "準備コマンドがデータベースを用意しない指定を持つ" do
    assert_match(/--skip-database/, SETUP.read)
  end

  test "準備コマンドが依存、データベース、一時ファイルを整える" do
    body = SETUP.read

    assert_match(/bundle check/, body)
    assert_match(/db:prepare/, body)
    assert_match(/log:clear tmp:clear/, body)
  end

  # 作り直しは worker の接続を切る必要があり、Compose の service を止める操作を
  # 伴う。コンテナの中からは行えないため、準備コマンドはこれを持たない。
  test "準備コマンドが破壊的な操作を持たない" do
    body = SETUP.read

    assert_no_match(/db:reset/, body)
    assert_no_match(/db:drop/, body)
  end

  # server を 1 process 起動するだけのコマンドは、Compose と役割が重なる。
  test "server を起動するだけのコマンドを持たない" do
    assert_not Rails.root.join("bin/dev").exist?, "bin/dev が残っている"
  end

  test "検証と手順書が同じ準備コマンドを呼ぶ" do
    [ "config/verify.rb", "README.md" ].each do |path|
      body = Rails.root.join(path).read

      assert_match(%r{bin/setup}, body, "#{path} が準備コマンドを呼んでいない")
      assert_no_match(/skip-server/, body, "#{path} が回避のための引数を付けている")
    end
  end
end
