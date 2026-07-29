require "csv"

# 部門の書き出し。
# 取り込みは、階層の指定が絡み順序に依存するため、現時点では扱わない。
class DepartmentCsv
  HEADERS = %w[name code parent_code position].freeze

  def initialize(organization)
    @organization = organization
  end

  def export
    CSV.generate(headers: HEADERS, write_headers: true) do |csv|
      @organization.departments.ordered.includes(:parent).each do |department|
        csv << [ department.name, department.code, department.parent&.code, department.position ]
      end
    end
  end
end
