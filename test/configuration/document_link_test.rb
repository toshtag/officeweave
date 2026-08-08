require "test_helper"

# 文書どうしの link が、実在する先を指していることを確かめる。
#
# 見出しまで見る。file だけを見る検査では、文書を分けたときに壊れた
# `#見出し` を素通りさせる。実際に素通りした。文書を移したあと、
# 移す前の見出しを指す link が 2 本残っていた。
class DocumentLinkTest < ActiveSupport::TestCase
  DOCUMENTS = %w[README.md CONTRIBUTING.md SECURITY.md CHANGELOG.md].freeze
  DIRECTORIES = %w[docs].freeze

  # 文書の中の link。画像と、外部の宛先は対象にしない。
  LINK = /\[[^\]]*\]\(([^)\s]+)\)/

  test "指した file が実在する" do
    missing = each_link.filter_map do |source, href, path, _|
      "#{source} -> #{href}" unless path.exist?
    end

    assert_empty missing, "指した先がありません:\n#{missing.join("\n")}"
  end

  test "指した見出しが実在する" do
    # 検査そのものが働くことを、決めた題材で確かめる。
    body = "# 題\n\n## ある見出し\n"

    assert_includes anchors_in(body), "ある見出し"
    assert_not_includes anchors_in(body), "無い見出し"

    missing = each_link.filter_map do |source, href, path, anchor|
      next if anchor.nil? || !path.exist? || path.directory?
      next if anchors_in(path.read).include?(anchor)

      "#{source} -> #{href}"
    end

    assert_empty missing, "指した見出しがありません:\n#{missing.join("\n")}"
  end

  private
    def each_link
      return enum_for(:each_link) unless block_given?

      documents.each do |source|
        source.read.scan(LINK).flatten.each do |href|
          next if href.start_with?("http", "mailto:", "#")

          target, anchor = href.split("#", 2)

          yield source.relative_path_from(Rails.root), href,
                source.dirname.join(target).cleanpath, anchor&.then { |a| decode(a) }
        end
      end
    end

    def documents
      DOCUMENTS.map { |name| Rails.root.join(name) }.select(&:exist?) +
        DIRECTORIES.flat_map { |dir| Rails.root.glob("#{dir}/**/*.md") }
    end

    # 見出しから作られる anchor。日本語はそのまま残り、空白は - になる。
    def anchors_in(body)
      body.scan(/^#+\s+(.+)$/).flatten.map do |heading|
        heading.strip.downcase.gsub(/[^\p{Word}\s-]/, "").tr(" ", "-")
      end
    end

    def decode(anchor)
      anchor.include?("%") ? CGI.unescape(anchor) : anchor
    end
end
