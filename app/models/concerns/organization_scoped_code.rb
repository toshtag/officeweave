# 組織の配下に置く識別子。
#
# 設備・備品、部門、申請種別、文書の分類が持つ。利用者が決める短い文字列で、
# CSV の取り込みや外部との連携で記録を指すために使う。表示名とは別に持つのは、
# 名称を変えても指し先が変わらないようにするためである。
#
# 契約は、正規化、必須、最大長、書式、組織の中での一意性の 5 つからなる。
# 模型ごとに書き写すと、条件を変えたときに一部だけが残る。とくに一意性の
# 範囲を落としても保存はでき、データベースの索引が拒むまで気付けない。
#
# 組織そのものの識別子はここに含めない。書式は同じだが、一意性の範囲が
# 組織の中ではなく全体である。範囲を選ぶ指定を足すと、この concern は
# 「識別子らしきものの検証」になり、読んで契約が分かる利点を失う。
module OrganizationScopedCode
  extend ActiveSupport::Concern

  # CSV の列や URL の一部として扱える長さに収める。
  MAXIMUM_LENGTH = 50

  # 先頭は英数字とする。記号で始まる値を許すと、並び順と URL の組み立てで
  # 扱いが分かれる。大文字と前後の空白は拒まず、正規化して受け取る。
  FORMAT = /\A[a-z0-9][a-z0-9_-]*\z/

  included do
    normalizes :code, with: ->(value) { value.strip.downcase }

    validates :code, presence: true, length: { maximum: MAXIMUM_LENGTH },
                     format: { with: FORMAT },
                     uniqueness: { scope: :organization_id }
  end
end
