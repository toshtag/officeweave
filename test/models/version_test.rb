require "test_helper"

class VersionTest < ActiveSupport::TestCase
  test "版数が定義されている" do
    assert_match(/\A\d+\.\d+\.\d+\z/, OfficeWeave::VERSION)
  end

  test "版数の出所は VERSION ファイルだけとする" do
    assert_equal Rails.root.join("VERSION").read.strip, OfficeWeave::VERSION
  end

  test "変更履歴に現在の版数が記載されている" do
    changelog = Rails.root.join("CHANGELOG.md").read

    assert_includes changelog, "## #{OfficeWeave::VERSION}"
  end
end
