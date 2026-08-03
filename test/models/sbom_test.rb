require "test_helper"
require "json"

# 部品表。
#
# 何を取り込んで配布しているのかを、外から読める形で出す。脆弱性の報告を
# 受けた側が、自分の環境が対象かどうかを確かめられるようにする。
#
# 出すのは、この製品が取り込んでいるものだけとする。実行環境の情報や
# 設定の値は含めない。部品表は組織の外へ渡ることがある。
class SbomTest < ActiveSupport::TestCase
  setup do
    @document = JSON.parse(Sbom.new.to_json)
  end

  test "CycloneDX の形式で出す" do
    assert_equal "CycloneDX", @document["bomFormat"]
    assert_equal Sbom::SPEC_VERSION, @document["specVersion"]
    assert_equal 1, @document["version"]
  end

  test "この製品を対象として示す" do
    subject = @document.dig("metadata", "component")

    assert_equal "application", subject["type"]
    assert_equal "officeweave", subject["name"]
    assert_equal OfficeWeave::VERSION, subject["version"]
  end

  test "取り込んでいるものを並べる" do
    names = @document["components"].map { |component| component["name"] }

    assert_includes names, "rails"
    assert_includes names, "pg"
    assert_includes names, "jwt"
  end

  test "版と識別子を持つ" do
    rails = @document["components"].detect { |component| component["name"] == "rails" }

    assert_equal Rails.version, rails["version"]
    assert_equal "pkg:gem/rails@#{Rails.version}", rails["purl"]
    assert_equal "library", rails["type"]
  end

  test "分かる範囲でライセンスを持つ" do
    rails = @document["components"].detect { |component| component["name"] == "rails" }

    assert_includes rails["licenses"].map { |license| license.dig("license", "id") }, "MIT"
  end

  test "ライセンスが分からないものも並べる" do
    # 落とすと、部品表としての用を果たさない。
    assert_equal Sbom.new.components.size, @document["components"].size
  end

  test "間接の依存も並べる" do
    names = @document["components"].map { |component| component["name"] }

    # rails が必要とし、そのさらに先で必要とされるもの。
    assert_includes names, "activesupport"
    assert_includes names, "concurrent-ruby"
  end

  test "手元の道具は並べない" do
    # 配布するものの部品表である。開発と試験だけで使うものは含めない。
    names = @document["components"].map { |component| component["name"] }

    %w[rubocop brakeman bundler-audit capybara debug selenium-webdriver].each do |name|
      refute_includes names, name
    end
  end

  test "同じものを 2 度並べない" do
    names = @document["components"].map { |component| component["name"] }

    assert_equal names.uniq.size, names.size
  end

  test "実行環境の情報を含めない" do
    # 部品表は組織の外へ渡ることがある。
    text = @document.to_json

    refute_includes text, ENV.fetch("DATABASE_PASSWORD", "no-password-set")
    refute_includes text, "SECRET_KEY_BASE"
    refute_includes text, Rails.root.to_s
  end

  test "読める JSON として出す" do
    assert_nothing_raised { JSON.parse(Sbom.new.to_json) }
  end

  test "並びは名前の順にそろえる" do
    # 並びが実行のたびに変わると、版の間の差分が読めない。
    names = @document["components"].map { |component| component["name"] }

    assert_equal names.sort, names
  end
end
