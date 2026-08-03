require "test_helper"

# 環境変数の雛形と設定の文書が、構成の要求から遅れないようにする。
#
# 変数を足す場所は compose の構成ファイルであり、そこへ足しただけでは
# 利用者には伝わらない。README は .env.example を複製する手順であるため、
# 雛形に無い変数は、必須であっても設定されないまま起動を試すことになる。
#
# 実際、配布用の構成が必須とする SECRET_KEY_BASE が、雛形にも設定の文書にも
# 無い状態が残っていた。書き写す先が 3 か所あり、1 か所だけ足りないことに
# 気付く仕組みが無かった。
class EnvironmentTemplateTest < ActiveSupport::TestCase
  COMPOSE_FILES = %w[compose.yaml compose.production.yaml compose.database.yaml].freeze

  TEMPLATE = ".env.example"
  DOCUMENT = "docs/development/configuration.md"

  # compose 自身が与える変数。利用者が `.env` へ書くものではない。
  #
  # 雛形と設定の文書は、利用者が設定するものの一覧である。ここへ載せると
  # 書き換えてよいものに見える。project 名は開発用と配布用を分ける拠り所で
  # あり、手元で書き換えられると、片方の `down -v` がもう片方を消し得る。
  SUPPLIED_BY_COMPOSE = %w[COMPOSE_PROJECT_NAME].freeze

  # 構成ファイルが `${NAME}` の形で参照する変数。
  # 既定値や `:?` の指定は、名前の後ろに続くため名前だけを取る。
  def self.referenced_variables
    COMPOSE_FILES.flat_map { |path| Rails.root.join(path).read.scan(/\$\{([A-Z_]+)/) }
      .flatten.uniq.sort - SUPPLIED_BY_COMPOSE
  end

  test "構成ファイルが参照する変数が、すべて雛形にある" do
    template = Rails.root.join(TEMPLATE).read

    missing = self.class.referenced_variables.reject do |name|
      # 行ごとコメントアウトした未設定も、雛形に載っているものとして扱う。
      # 設定しないことが既定である変数は、その形で示している。
      template.match?(/^#?\s*#{Regexp.escape(name)}=/)
    end

    assert_empty missing, "#{TEMPLATE} に無い: #{missing.join(', ')}"
  end

  test "構成ファイルが参照する変数が、すべて設定の文書にある" do
    document = Rails.root.join(DOCUMENT).read

    missing = self.class.referenced_variables.reject { |name| document.include?("`#{name}`") }

    assert_empty missing, "#{DOCUMENT} に無い: #{missing.join(', ')}"
  end

  test "雛形が挙げる変数が、すべて設定の文書にある" do
    document = Rails.root.join(DOCUMENT).read

    declared = Rails.root.join(TEMPLATE).read.scan(/^#?\s*([A-Z_]+)=/).flatten.uniq
    missing = declared.reject { |name| document.include?("`#{name}`") }

    assert_empty missing, "#{DOCUMENT} に無い: #{missing.join(', ')}"
  end
end
