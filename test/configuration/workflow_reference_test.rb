require "test_helper"
require "yaml"

# 継続的インテグレーションが参照する外部の動作。
#
# 参照を可変の名前（v4 のような移動する tag）で書くと、参照先の中身が
# 後から変わる。検証を実行する環境で、こちらの意図しない処理が動き得る。
#
# 固定するのは commit の識別子とする。tag は付け替えられる。
class WorkflowReferenceTest < ActiveSupport::TestCase
  WORKFLOWS = Rails.root.glob(".github/workflows/*.yml")

  # commit の識別子。40 桁の 16 進数だけを認める。
  PINNED = /\A[0-9a-f]{40}\z/

  test "workflow が存在する" do
    assert_not_empty WORKFLOWS
  end

  test "外部の動作の参照は commit の識別子で固定する" do
    unpinned = references.reject { |reference| PINNED.match?(reference[:version]) }

    assert_empty unpinned.map { |reference| "#{reference[:file]}: #{reference[:raw]}" }
  end

  test "固定した参照には、読める版を注記する" do
    # 識別子だけでは、どの版を指しているのかが読めない。
    without_comment = references.reject { |reference| reference[:comment].present? }

    assert_empty without_comment.map { |reference| "#{reference[:file]}: #{reference[:raw]}" }
  end

  test "参照を 1 件以上見つけている" do
    # 書き方が変わって拾えなくなった場合に、検査が空振りしないようにする。
    assert_operator references.size, :>=, 1
  end

  private
    # uses: の行を、参照と注記へ分けて読む。
    #
    # YAML として読まずに行で読む。注記（# v4.4.0）は YAML の解析では落ちる。
    def references
      WORKFLOWS.flat_map do |path|
        path.readlines.filter_map do |line|
          match = line.match(/^\s*uses:\s*(?<action>[^@\s]+)@(?<version>\S+)(?:\s*#\s*(?<comment>.+))?$/)
          next if match.nil?

          { file: path.basename.to_s, raw: line.strip, action: match[:action],
            version: match[:version], comment: match[:comment]&.strip }
        end
      end
    end
end
