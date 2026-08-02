require "test_helper"

# 組織の配下に置く識別子の契約を、模型を横断して 1 か所で確かめる。
#
# 同じ契約が模型ごとに書かれていると、条件を変えたときに一部だけが残る。
# とくに組織の中での一意性は、落としても保存はできてしまい、
# データベースの索引が拒むまで気付けない。
class OrganizationScopedCodeTest < ActiveSupport::TestCase
  # この契約を持つ模型と、他の必須の属性を埋めるための組み立て。
  BUILDERS = {
    "設備・備品" => ->(organization, attributes) { organization.resources.new(name: "名称", **attributes) },
    "部門" => ->(organization, attributes) { organization.departments.new(name: "名称", **attributes) },
    "申請種別" => ->(organization, attributes) { organization.request_types.new(name: "名称", **attributes) },
    "文書の分類" => ->(organization, attributes) { organization.document_categories.new(name: "名称", **attributes) }
  }.freeze

  setup do
    @main = organizations(:main)
    @other = organizations(:other)
  end

  test "契約を持つ模型が、いずれも識別子を必須とする" do
    each_model do |name, build|
      record = build.call(@main, code: "")

      assert_not record.valid?, "#{name} が空の識別子を受け付けている"
      assert_includes record.errors.details[:code], { error: :blank }
    end
  end

  test "契約を持つ模型が、いずれも 50 文字を超える識別子を拒む" do
    each_model do |name, build|
      assert build.call(@main, code: "a" * 50).valid?, "#{name} が 50 文字を拒んでいる"

      record = build.call(@main, code: "a" * 51)

      assert_not record.valid?, "#{name} が 51 文字を受け付けている"
      assert_includes record.errors.details[:code].map { |detail| detail[:error] }, :too_long
    end
  end

  # 先頭の記号を許すと、並び順や URL の組み立てで扱いが分かれる。
  test "契約を持つ模型が、いずれも許した文字だけを受け付ける" do
    each_model do |name, build|
      assert build.call(@main, code: "a0_-").valid?, "#{name} が許すべき識別子を拒んでいる"

      [ "_leading", "-leading", "Upper Case", "日本語", "with space", "dot.separated" ].each do |invalid|
        record = build.call(@main, code: invalid)

        assert_not record.valid?, "#{name} が #{invalid.inspect} を受け付けている"
      end
    end
  end

  test "契約を持つ模型が、いずれも前後の空白と大文字を正規化する" do
    each_model do |name, build|
      record = build.call(@main, code: "  ROOM-A  ")

      assert_equal "room-a", record.code, "#{name} が識別子を正規化していない"
    end
  end

  test "契約を持つ模型が、いずれも同じ組織での重複を拒む" do
    each_model do |name, build|
      existing = build.call(@main, code: "shared-code")
      existing.save!

      duplicate = build.call(@main, code: "shared-code")

      assert_not duplicate.valid?, "#{name} が同じ組織での重複を受け付けている"
      assert_includes duplicate.errors.details[:code], { error: :taken, value: "shared-code" }
    end
  end

  test "契約を持つ模型が、いずれも別の組織であれば同じ識別子を許す" do
    each_model do |name, build|
      build.call(@main, code: "shared-code").save!

      assert build.call(@other, code: "shared-code").valid?,
             "#{name} が別の組織での同じ識別子を拒んでいる"
    end
  end

  # 大文字で送られた重複も、正規化のあとで判定する。
  test "契約を持つ模型が、正規化したあとの重複を拒む" do
    each_model do |name, build|
      build.call(@main, code: "shared-code").save!

      duplicate = build.call(@main, code: "  SHARED-CODE  ")

      assert_not duplicate.valid?, "#{name} が正規化後の重複を受け付けている"
    end
  end

  # 組織の識別子は全体で一意である。同じ形をしているが契約が違う。
  test "組織の識別子は、この契約とは別に全体で一意である" do
    duplicate = Organization.new(name: "別の見本商事", code: @main.code)

    assert_not duplicate.valid?
    assert_includes duplicate.errors.details[:code], { error: :taken, value: @main.code }
  end

  private
    # 契約を持つ模型をすべて通す。1 つでも欠けていれば、その模型の名前が
    # 失敗の理由に出る。模型は別の表を使うため、同じ識別子で保存しても
    # 互いに影響しない。
    def each_model(&block)
      BUILDERS.each(&block)
    end
end
