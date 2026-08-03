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

  private
    # on: は YAML の真偽値として読まれる。書き方を変えずに両方を受ける。
    def triggers(path)
      document = YAML.safe_load_file(path, aliases: true)

      document["on"] || document[true]
    end
end
