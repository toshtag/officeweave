require "bundler"
require "json"

# 部品表。
#
# 何を取り込んで配布しているのかを、外から読める形で出す。脆弱性の報告を
# 受けた側が、自分の環境が対象かどうかを確かめられるようにする。
#
# 形式は CycloneDX とする。仕様のうち使うのは、対象と部品の一覧だけである。
# 出力は JSON の並べ替えだけであり、依存を足さずに組み立てられる。
#
# 出すのは、この製品が取り込んでいるものだけとする。実行環境の情報や設定の値は
# 含めない。部品表は組織の外へ渡ることがある。
class Sbom
  SPEC_VERSION = "1.5".freeze

  # 部品の種類。取り込んでいる gem はいずれもライブラリである。
  COMPONENT_TYPE = "library".freeze

  def to_json(*)
    {
      bomFormat: "CycloneDX",
      specVersion: SPEC_VERSION,
      version: 1,
      metadata: { component: subject },
      components: components
    }.to_json
  end

  # 取り込んでいるものの一覧。名前の順にそろえる。
  #
  # 並びが実行のたびに変わると、版の間の差分が読めない。
  def components
    @components ||= specifications.sort_by(&:name).map { |spec| component_for(spec) }
  end

  private
    def subject
      { type: "application", name: "officeweave", version: OfficeWeave::VERSION }
    end

    # 実行に使う gem の一覧。開発と試験だけで使うものは含めない。
    #
    # 配布するものの部品表であり、手元の道具は配布していない。
    #
    # 間接の依存も含める。取り込んでいるものは、直に書いたものだけではない。
    # 1 段だけ辿る形にすると、その先が抜ける。辿り終わるまで広げる。
    def specifications
      definition = Bundler.definition
      by_name = definition.specs.index_by(&:name)
      queue = definition.dependencies.reject { |dependency| development_only?(dependency) }.map(&:name)
      collected = Set.new

      while (name = queue.shift)
        spec = by_name[name]
        next if spec.nil? || !collected.add?(name)

        queue.concat(spec.dependencies.map(&:name))
      end

      collected.filter_map { |name| by_name[name] }
    end

    def development_only?(dependency)
      groups = dependency.groups.map(&:to_s)

      groups.any? && (groups - %w[development test]).empty?
    end

    def component_for(spec)
      component = {
        type: COMPONENT_TYPE,
        name: spec.name,
        version: spec.version.to_s,
        purl: "pkg:gem/#{spec.name}@#{spec.version}"
      }

      licenses = Array(spec.respond_to?(:licenses) ? spec.licenses : nil).compact_blank
      component[:licenses] = licenses.map { |license| { license: { id: license } } } if licenses.any?

      component
    end
end
