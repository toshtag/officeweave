# 組織をまたぐ参照を拒む。
#
# 組織で絞った一覧、集計、通知は、参照が同じ組織に閉じていることを前提に
# している。境界を越えた参照が 1 件でも保存されると、その前提が崩れ、
# 他組織の利用者名や予定の件名が読める経路になる。
#
# 判定そのものは模型ごとに同じ形になるため、宣言だけを各模型へ置く。
# 書き写す形にすると、模型を追加したときに欠けても気付けない。
module OrganizationBoundary
  extend ActiveSupport::Concern

  class_methods do
    # 指定した関連が、基準となる組織と同じ組織に属することを求める。
    #
    # 基準は既定で自身の organization_id とする。組織を直接持たない結合や
    # 履歴の記録では、組織を持つ関連の名前を `of:` へ渡す。
    def belongs_to_same_organization(*names, of: nil)
      validate do
        expected = of ? OrganizationBoundary.organization_id_of(self, of) : organization_id
        next if expected.nil?

        names.each do |name|
          actual = OrganizationBoundary.organization_id_of(self, name)
          next if actual.nil? || actual == expected

          errors.add(name, :different_organization)
        end
      end
    end
  end

  # 関連の組織を読む。
  #
  # 多態の関連は、組織を持たない記録も指し得る。判定できない場合は nil を
  # 返し、この検証では何も言わない。組織を持たない記録との結び付きを
  # 拒むかどうかは、その関連を定義した模型が決める。
  def self.organization_id_of(record, name)
    target = record.public_send(name)
    return nil unless target.respond_to?(:organization_id)

    target.organization_id
  end
end
