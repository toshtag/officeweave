require "csv"

# 利用者の入出力。
#
# 取り込みは、1 行でも誤りがあれば何も保存しない。
# 一部だけ取り込まれると、どこまで反映されたか分からなくなる。
class UserCsv
  HEADERS = %w[name email_address role locale departments].freeze

  Result = Struct.new(:created_count, :updated_count, :errors, keyword_init: true) do
    def success? = errors.empty?
  end

  def initialize(organization)
    @organization = organization
  end

  def export
    CSV.generate(headers: HEADERS, write_headers: true) do |csv|
      @organization.users.ordered.includes(memberships: :department).each do |user|
        csv << [
          user.name,
          user.email_address,
          user.role,
          user.locale,
          user.memberships.map { |membership| membership.department.code }.join(" ")
        ]
      end
    end
  end

  # メールアドレスを手がかりに、既存の利用者は更新し、なければ作る。
  # パスワードは扱わない。取り込みで資格情報を配れる状態にしない。
  def import(content)
    errors = []
    created = 0
    updated = 0

    ActiveRecord::Base.transaction do
      rows(content).each_with_index do |row, index|
        user = find_or_build(row["email_address"])
        was_new = user.new_record?

        assign(user, row)

        if user.save
          apply_departments(user, row["departments"])
          was_new ? created += 1 : updated += 1
        else
          # 行番号は見出しを含めた表示上の位置で伝える。
          errors << { line: index + 2, messages: user.errors.full_messages }
        end
      end

      raise ActiveRecord::Rollback if errors.any?
    end

    Result.new(created_count: errors.empty? ? created : 0,
               updated_count: errors.empty? ? updated : 0,
               errors: errors)
  rescue CSV::MalformedCSVError => error
    Result.new(created_count: 0, updated_count: 0,
               errors: [ { line: 0, messages: [ error.message ] } ])
  end

  private
    def rows(content)
      CSV.parse(content, headers: true)
    end

    def find_or_build(email_address)
      normalized = email_address.to_s.strip.downcase

      @organization.users.find_by(email_address: normalized) || @organization.users.new
    end

    def assign(user, row)
      user.name = row["name"]
      user.email_address = row["email_address"]
      user.role = row["role"].presence || "member"
      user.locale = row["locale"].presence
      # 新しい利用者には、本人が変更するまで使えない値を割り当てる。
      user.password = SecureRandom.hex(32) if user.new_record?
    rescue ArgumentError
      # 知らない権限が指定された場合は、検証で拒否できる形にする。
      user.errors.add(:role, :inclusion)
    end

    def apply_departments(user, codes)
      wanted = @organization.departments.where(code: codes.to_s.split)
      user.memberships.where.not(department_id: wanted.select(:id)).destroy_all

      wanted.each do |department|
        user.memberships.find_or_create_by!(department: department)
      end
    end
end
