require "csv"

# 部門の書き出しと取り込み。
#
# 生成と解析は CsvTransfer を通す。利用者 CSV と同じ形式で扱うため、
# 数式として解釈され得るセルの保護と、その復元も同じ経路で行う。
#
# 取り込みは、1 行でも誤りがあれば何も保存しない。一部だけ取り込まれると、
# どこまで反映されたか分からなくなる。
#
# 行の並びには依存させない。書き出しの並びは position と名前で決まるため、
# 上位が先に来るとは限らない。並びを守らせると、書き出したものを
# そのまま戻せない場合がある。
class DepartmentCsv
  HEADERS = %w[name code parent_code position].freeze

  Result = Struct.new(:created_count, :updated_count, :errors, keyword_init: true) do
    def success? = errors.empty?
  end

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

  # 識別子を手がかりに、既存の部門は更新し、なければ作る。
  #
  # 2 段に分ける。先に名前と並びを保存し、そのあとで上位を結び付ける。
  # 1 行ずつ完結させると、上位が後ろの行にある場合に解決できない。
  def import(content)
    errors = []
    created = 0
    updated = 0

    ActiveRecord::Base.transaction do
      rows = parse(content)
      errors.concat(duplicate_code_errors(rows))

      if errors.empty?
        saved = save_departments(rows, errors) { |was_new| was_new ? created += 1 : updated += 1 }
        assign_parents(rows, saved, errors) if errors.empty?
      end

      raise ActiveRecord::Rollback if errors.any?
    end

    Result.new(created_count: errors.empty? ? created : 0,
               updated_count: errors.empty? ? updated : 0,
               errors: errors)
  rescue CSV::MalformedCSVError => error
    Result.new(created_count: 0, updated_count: 0, errors: [ { line: 0, messages: [ error.message ] } ])
  end

  private
    def parse(content)
      CsvTransfer.parse(content).map.with_index { |row, index| { row: row, line: index + 2 } }
    end

    # 同じ識別子が 2 行にある場合は誤りとする。
    # どちらが最後の状態なのかを、取り込む側が決めてはならない。
    def duplicate_code_errors(rows)
      seen = {}

      rows.filter_map do |entry|
        code = entry[:row]["code"].to_s

        next if code.blank?

        if seen[code].nil?
          seen[code] = entry[:line]
          next
        end

        { line: entry[:line], messages: [ duplicate_message(code, seen[code]) ] }
      end
    end

    def save_departments(rows, errors)
      rows.filter_map do |entry|
        row = entry[:row]
        department = find_or_build(row["code"])
        was_new = department.new_record?

        department.name = row["name"]
        department.code = row["code"]
        # 列が無い場合と空欄の場合は、今の並びを変えない。
        # 新しい部門では、表の既定（0）に任せる。
        department.position = row["position"] if row.header?("position") && row["position"].present?

        if department.save
          yield(was_new)
          [ row["code"].to_s, { department: department, entry: entry } ]
        else
          errors << { line: entry[:line], messages: department.errors.full_messages }
          nil
        end
      end.to_h
    end

    # 上位は、この取り込みで保存した分と、既にある部門の両方から解決する。
    #
    # 列そのものが無い場合は階層を変えない。空欄の場合は最上位へ移す。
    # 列の有無で意味が変わるのは、利用者 CSV の所属と同じ扱いである。
    def assign_parents(rows, saved, errors)
      rows.each do |entry|
        row = entry[:row]
        next unless row.header?("parent_code")

        record = saved[row["code"].to_s]
        next if record.nil?

        parent_code = row["parent_code"].to_s

        if parent_code.blank?
          record[:department].update(parent: nil)
          next
        end

        parent = saved.dig(parent_code, :department) || @organization.departments.find_by(code: parent_code)

        if parent.nil?
          errors << { line: entry[:line], messages: [ unknown_parent_message(parent_code) ] }
        elsif !record[:department].update(parent: parent)
          errors << { line: entry[:line], messages: record[:department].errors.full_messages }
        end
      end
    end

    # 自組織の部門だけを対象にする。他の組織の同じ識別子は別の記録である。
    def find_or_build(code)
      normalized = code.to_s.strip

      @organization.departments.find_by(code: normalized) || @organization.departments.new
    end

    def duplicate_message(code, first_line)
      I18n.t("department_csv.duplicate_code", code: code, line: first_line)
    end

    def unknown_parent_message(code)
      I18n.t("department_csv.unknown_parent", code: code)
    end
end
