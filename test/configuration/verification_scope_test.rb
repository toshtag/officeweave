require "test_helper"
require "yaml"

# 検証をいつ走らせるかを固定する。
#
# 変更を出すたびに走らせるものと、main へ入ったあとにまとめて走らせるものを
# 分けている。分けた以上、片方が黙って走らなくなる余地ができる。
#
# 走らなくなっても、その場では何も失敗しない。緑のまま、確かめていない状態が
# 続く。気付くのは、配布したものが動かないときである。
class VerificationScopeTest < ActiveSupport::TestCase
  PULL_REQUEST = Rails.root.join(".github/workflows/verify.yml").freeze
  OPERATIONS = Rails.root.join(".github/workflows/operations.yml").freeze

  test "変更を出すたびに走る検証がある" do
    assert_includes triggers(PULL_REQUEST).keys, "pull_request"
  end

  test "main へ入ったものは運用の検証まで通る" do
    assert_equal [ "main" ], triggers(OPERATIONS).dig("push", "branches")
  end

  # 脆弱性の検査は、こちらが何も変えなくても結果が変わる。
  # main への push だけにすると、変更が止まっている間は検査も止まる。
  test "運用の検証は週次でも走る" do
    assert_not_empty triggers(OPERATIONS)["schedule"].to_a
  end

  # 配布用の構成やホスト側の手順へ触れる変更は、マージの前に確かめたい。
  test "運用の検証は手動でも走らせられる" do
    assert_includes triggers(OPERATIONS).keys, "workflow_dispatch"
  end

  # 起動と後片付けを含む仕事は 1 回 2 分前後かかる。変更を出すたびに走らせると、
  # その待ち時間が寄稿者へそのまま乗る。
  test "変更を出すたびに走る検証で配布用の構成を起動しない" do
    # 食い違った箇所を出す。ファイルの全体を出しても、どこが原因かは読めない。
    started = PULL_REQUEST.readlines.grep(/compose\.production\.yaml/).map(&:strip)

    assert_empty started, "#{PULL_REQUEST.basename} が配布用の構成を起動している"
  end

  # 範囲を分けて同時に走らせている。挙げ忘れた範囲は誰も実行しない。
  # 実行されなくても、残りの範囲は緑になる。
  test "config/verify.rb が持つ範囲はすべて自動実行で走る" do
    assert_equal defined_scopes.sort, executed_scopes.sort
  end

  # 分けたうちの 1 つを挙げ忘れると、その範囲のテストが誰にも実行されない。
  test "テストの分割は数え上げた分だけ挙がる" do
    shards = matrix.filter_map { |entry| entry["shard"].presence }
    total = shards.filter_map { |shard| shard.split("/").last.to_i }.uniq

    assert_equal 1, total.size, "分割の数が食い違っている: #{shards.join("、")}"
    assert_equal (1..total.first).map { |index| "#{index}/#{total.first}" }.sort, shards.sort
  end

  # 止めないと、寄稿者は自分が捨てた commit の結果を待つことになる。
  test "同じ枝で続けて出した場合は古い実行を止める" do
    concurrency = YAML.safe_load_file(PULL_REQUEST, aliases: true)["concurrency"]

    assert_not_nil concurrency, "#{PULL_REQUEST.basename} に重なりの扱いが無い"
    assert_includes concurrency["group"].to_s, "github.ref"
    assert_includes concurrency["cancel-in-progress"].to_s, "refs/heads/main"
  end

  # 手順を workflow へ写すと、一覧が 2 か所になる。config/verify.rb へ検査を
  # 足しても自動実行がそれを流さない状態が、黙って生まれる。
  test "検証の手順を workflow へ書き写さない" do
    copied = COMMANDS.select { |command| PULL_REQUEST.read.include?(command) }

    assert_empty copied, "#{PULL_REQUEST.basename} へ手順が写っている"
  end

  private
    # config/verify.rb が呼ぶもの。ここへ現れたら、一覧が 2 か所になっている。
    COMMANDS = %w[bin/rubocop bin/brakeman bin/bundler-audit test:except_browser].freeze

    VERIFY = Rails.root.join("config/verify.rb").freeze

    # on: は YAML の真偽値として読まれる。書き方を変えずに両方を受ける。
    def triggers(path)
      document = YAML.safe_load_file(path, aliases: true)

      document["on"] || document[true]
    end

    # 分け方を持つ仕事の一覧。仕事の名前では探さない。名前を変えただけで
    # 検査が空振りする。
    def matrix
      YAML.safe_load_file(PULL_REQUEST, aliases: true)["jobs"].values
          .filter_map { |job| job.dig("strategy", "matrix", "include") }.flatten
    end

    # 範囲は 2 通りの渡し方がある。分け方から渡すものと、直接書くものである。
    def executed_scopes
      from_matrix = matrix.filter_map { |entry| entry["scope"] }
      written = PULL_REQUEST.read.scan(%r{bin/verify\s+(\w+)}).flatten

      (from_matrix + written).uniq
    end

    # 手元での既定（all）は分けた側には現れない。分けた範囲だけを取り出す。
    def defined_scopes
      listed = VERIFY.read[/^SCOPES = %w\[([^\]]+)\]/, 1]

      assert_not_nil listed, "config/verify.rb から範囲を読み取れない"

      listed.split - [ "all" ]
    end
end
