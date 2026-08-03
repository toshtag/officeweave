require "test_helper"

# 画面が名指しで出す属性名に、両方の言語の訳があることを固定する。
#
# 訳が無くても例外にならない。Rails が属性の名前から作った英語
# （Ip address など）が、日本語の画面へそのまま並ぶ。実際、ログイン中の
# 端末の一覧で、接続元の列だけがその状態だった。
#
# 様式（form.field）の名札は見ない。どの模型に対する様式かは、その場の
# form_with が決めており、テンプレートの字面からは辿れない。部門の画面に
# 所属の様式が置かれているように、置き場所からも決まらない。
class LocaleAttributeTest < ActiveSupport::TestCase
  LOCALES = %i[ja en].freeze
  # 例: AuditEvent.human_attribute_name(:actor)
  REFERENCE = /\b([A-Z]\w+)\.human_attribute_name\(:(\w+)\)/

  test "画面が名指しで出す属性名に、訳がある" do
    missing = references.reject do |model, attribute|
      LOCALES.all? { |locale| I18n.exists?("activerecord.attributes.#{model}.#{attribute}", locale) }
    end

    assert_empty missing.map { |model, attribute| "#{model}.#{attribute}" },
                 "訳の無い属性名を画面へ出している"
  end

  # 上の 1 件は、集める側が壊れると、何も確かめないまま成功する。
  test "画面から属性名の参照を集められる" do
    assert_operator references.size, :>=, 10, "参照を集められていない"
  end

  private
    def references
      @references ||= Rails.root.glob("app/views/**/*.erb").flat_map { |path| references_in(path) }.uniq
    end

    def references_in(path)
      path.read.scan(REFERENCE).filter_map do |model, attribute|
        [ model.underscore, attribute ] if model.safe_constantize.respond_to?(:human_attribute_name)
      end
    end
end
