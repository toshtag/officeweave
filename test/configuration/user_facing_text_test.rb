require "test_helper"

# 画面へ出る語句の置き場所。
#
# 共通条件 10 は、画面に出る語句が対応する 2 つの言語にそろうことを求める。
# 鍵がそろっていることは locale_symmetry_test が保証する。ここで保証するのは、
# 画面が語句をロケールファイル経由で出していることである。
#
# 直接書いた語句は、鍵を持たないため対訳の対象にならない。鍵の一覧を
# いくら突き合わせても、直接書いた分だけは片方の言語のまま残る。
#
# コメントは対象から外す。読む相手は利用者ではなく、次に読む開発者である。
class UserFacingTextTest < ActiveSupport::TestCase
  # 日本語の文字。ここに当たる語句は、そのまま画面へ出れば対訳できない。
  JAPANESE = /[ぁ-んァ-ヶ一-龥]/

  # 画面と、画面へ語句を渡す側。
  #
  # 制御部は対象にしない。制御部が持つ日本語は、監査の割り当ての理由や
  # 認証を開く理由、記録にだけ残す失敗の理由であり、画面へは出ない。
  # 画面へ出す語句は、制御部からも t を通す。
  SOURCES = %w[app/views/**/*.erb app/helpers/**/*.rb].freeze

  test "画面へ語句を直接書いていない" do
    assert_empty offenders(Rails.root.glob("app/views/**/*.erb")),
                 "ロケールファイルを経由させる"
  end

  test "画面へ語句を渡す側にも、直接書いていない" do
    assert_empty offenders(Rails.root.glob("app/helpers/**/*.rb")), "ロケールファイルを経由させる"
  end

  test "制御部が画面へ返す語句も、ロケールファイルを経由する" do
    # 制御部が持つ日本語は、記録にだけ残す理由である。画面へ返す文面
    # （notice と alert）が t を通っていることを見る。
    direct = Rails.root.glob("app/controllers/**/*.rb").flat_map do |path|
      path.read.scan(/(?:notice|alert):\s*"([^"]*)"/).flatten
          .select { |text| JAPANESE.match?(text) }
          .map { |text| "#{path.relative_path_from(Rails.root)}: #{text}" }
    end

    assert_empty direct
  end

  test "2 つの言語の鍵がそろう検査がある" do
    # ここが無ければ、経由させているだけで対訳は保証されない。
    assert File.exist?(Rails.root.join("test/configuration/locale_symmetry_test.rb"))
  end

  test "見ているファイルが 1 つ以上ある" do
    # 抽出の条件を間違えると、1 件も見ないまま通る。
    assert_operator SOURCES.sum { |pattern| Rails.root.glob(pattern).size }, :>=, 60
    assert_operator Rails.root.glob("app/controllers/**/*.rb").size, :>=, 20
  end

  test "直接書いた語句を見つけられる" do
    # 検査そのものが働くことを、決めた文で確かめる。
    assert_predicate lines_with_text("<p>そのまま出す語句</p>\n"), :any?
    assert_empty lines_with_text("<%# 説明のためのコメント %>\n")
    assert_empty lines_with_text("<%#\n  複数行の説明。\n  続き。\n%>\n")
    assert_empty lines_with_text("<%= t(\"users.index.title\") %>\n")
    assert_empty lines_with_text("# Ruby の説明のコメント\n")
  end

  private
    def offenders(paths)
      paths.flat_map do |path|
        relative = path.relative_path_from(Rails.root)

        lines_with_text(path.read).map { |number, line| "#{relative}:#{number}: #{line}" }
      end
    end

    # 語句を直接書いている行を返す。コメントは取り除いてから見る。
    def lines_with_text(source)
      without_comments(source).each_with_index.filter_map do |line, index|
        [ index + 1, line.strip ] if JAPANESE.match?(line)
      end
    end

    # コメントを空行へ置き換える。行番号を保つため、消さずに置き換える。
    def without_comments(source)
      text = source.gsub(/<%#.*?%>/m) { |block| "\n" * block.count("\n") }

      text.lines.map { |line| line.lstrip.start_with?("#") ? "\n" : line }
    end
end
