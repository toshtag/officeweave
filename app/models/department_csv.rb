# 部門の書き出し。
#
# 生成は CsvTransfer を通す。利用者 CSV と同じ形式で書き出すため、
# 数式として解釈され得るセルの保護も同じ経路で行う。
#
# 取り込みは、階層の指定が絡み順序に依存するため、現時点では扱わない。
class DepartmentCsv
  HEADERS = %w[name code parent_code position].freeze

  def initialize(organization)
    @organization = organization
  end

  def export
    CsvTransfer.generate(headers: HEADERS) do |csv|
      @organization.departments.ordered.includes(:parent).each do |department|
        csv << [ department.name, department.code, department.parent&.code, department.position ]
      end
    end
  end
end
