# 動作確認用のデータ。
#
# 実在する個人や組織の情報は使わない。すべて架空の値とする。
# 何度実行しても同じ状態になるよう、識別子で対応づけて作り直す。
class DemoData
  PASSWORD = "officeweave-demo"

  ORGANIZATION = { name: "見本産業株式会社", code: "demo" }.freeze

  DEPARTMENTS = [
    { name: "経営企画部", code: "planning", position: 10 },
    { name: "営業部", code: "sales", position: 20 },
    { name: "営業部 東日本課", code: "sales-east", parent_code: "sales", position: 30 },
    { name: "開発部", code: "development", position: 40 },
    { name: "管理部", code: "administration", position: 50 }
  ].freeze

  USERS = [
    { name: "見本 管理者", email_address: "admin@demo.invalid", role: "administrator",
      department_code: "administration" },
    { name: "見本 営業一郎", email_address: "sales1@demo.invalid", role: "member",
      department_code: "sales" },
    { name: "見本 営業二郎", email_address: "sales2@demo.invalid", role: "member",
      department_code: "sales-east" },
    { name: "見本 開発花子", email_address: "dev1@demo.invalid", role: "member",
      department_code: "development", locale: "en" },
    { name: "見本 企画太郎", email_address: "planning1@demo.invalid", role: "member",
      department_code: "planning" }
  ].freeze

  RESOURCES = [
    { name: "会議室 A（8 名）", code: "room-a", capacity: 8, position: 10 },
    { name: "会議室 B（4 名）", code: "room-b", capacity: 4, position: 20 },
    { name: "貸出用ノート端末", code: "laptop", position: 30 }
  ].freeze

  REQUEST_TYPES = [
    { name: "休暇届", code: "leave", approver_code: "administration", position: 10 },
    { name: "経費精算", code: "expense", approver_code: "administration", position: 20 },
    { name: "備品購入申請", code: "purchase", approver_code: "planning", position: 30 }
  ].freeze

  DOCUMENT_CATEGORIES = [
    { name: "規程", code: "rules", position: 10 },
    { name: "手順書", code: "manuals", position: 20 }
  ].freeze

  def install
    ActiveRecord::Base.transaction do
      organization = find_or_create_organization
      departments = create_departments(organization)
      users = create_users(organization, departments)
      resources = create_resources(organization)

      counts = {
        "組織" => 1,
        "部門" => departments.size,
        "利用者" => users.size,
        "設備・備品" => resources.size,
        "申請種別" => create_request_types(organization, departments).size,
        "文書の分類" => create_document_categories(organization).size,
        "お知らせ" => create_announcements(organization, users, departments).size,
        "予定" => create_events(organization, users, departments).size,
        "予約" => create_reservations(organization, users, resources).size,
        "申請" => create_requests(organization, users).size,
        "文書" => create_documents(organization, users).size
      }

      counts
    end
  end

  private
    def find_or_create_organization
      Organization.find_or_create_by!(code: ORGANIZATION[:code]) { |record| record.name = ORGANIZATION[:name] }
    end

    def create_departments(organization)
      DEPARTMENTS.each_with_object({}) do |attributes, result|
        department = organization.departments.find_or_initialize_by(code: attributes[:code])
        department.name = attributes[:name]
        department.position = attributes[:position]
        department.parent = result[attributes[:parent_code]]
        department.save!

        result[attributes[:code]] = department
      end
    end

    def create_users(organization, departments)
      USERS.each_with_object({}) do |attributes, result|
        user = organization.users.find_or_initialize_by(email_address: attributes[:email_address])
        user.name = attributes[:name]
        user.role = attributes[:role]
        user.locale = attributes[:locale]
        user.password = PASSWORD
        user.save!

        department = departments[attributes[:department_code]]
        user.memberships.find_or_create_by!(department: department) { |m| m.primary = true }

        result[attributes[:email_address]] = user
      end
    end

    def create_resources(organization)
      RESOURCES.each_with_object({}) do |attributes, result|
        resource = organization.resources.find_or_initialize_by(code: attributes[:code])
        resource.assign_attributes(attributes.except(:code))
        resource.save!

        result[attributes[:code]] = resource
      end
    end

    def create_request_types(organization, departments)
      REQUEST_TYPES.each_with_object({}) do |attributes, result|
        request_type = organization.request_types.find_or_initialize_by(code: attributes[:code])
        request_type.name = attributes[:name]
        request_type.position = attributes[:position]
        # 承認の段は 1 段だけ用意する。動作確認では多段の必要が無く、
        # 段の構成そのものは画面から確かめられる。
        step = request_type.approval_steps.first || request_type.approval_steps.build(position: 10)
        step.approver_department = departments[attributes[:approver_code]]
        request_type.save!

        result[attributes[:code]] = request_type
      end
    end

    def create_document_categories(organization)
      DOCUMENT_CATEGORIES.each_with_object({}) do |attributes, result|
        category = organization.document_categories.find_or_initialize_by(code: attributes[:code])
        category.assign_attributes(attributes.except(:code))
        category.save!

        result[attributes[:code]] = category
      end
    end

    def create_announcements(organization, users, departments)
      return organization.announcements if organization.announcements.any?

      [
        organization.announcements.create!(
          author: users["admin@demo.invalid"], title: "年末年始の休業について",
          body: "12 月 29 日から 1 月 3 日まで休業します。緊急の連絡は管理部までお願いします。",
          visibility: "organization", published_at: 3.days.ago
        ),
        organization.announcements.create!(
          author: users["admin@demo.invalid"], title: "営業部の定例報告の変更",
          body: "今月から、定例報告は毎週水曜に変更します。",
          visibility: "departments", departments: [ departments["sales"] ], published_at: 1.day.ago
        )
      ]
    end

    def create_events(organization, users, departments)
      return organization.events if organization.events.any?

      [
        organization.events.create!(
          owner: users["admin@demo.invalid"], title: "全社朝礼",
          starts_at: 1.day.from_now.change(hour: 9), ends_at: 1.day.from_now.change(hour: 9, min: 30),
          visibility: "organization"
        ),
        organization.events.create!(
          owner: users["sales1@demo.invalid"], title: "営業部の週次会議",
          starts_at: 2.days.from_now.change(hour: 14), ends_at: 2.days.from_now.change(hour: 15),
          visibility: "departments", departments: [ departments["sales"] ]
        )
      ]
    end

    def create_reservations(organization, users, resources)
      return organization.reservations if organization.reservations.any?

      [
        organization.reservations.create!(
          resource: resources["room-a"], reserver: users["sales1@demo.invalid"],
          starts_at: 1.day.from_now.change(hour: 13), ends_at: 1.day.from_now.change(hour: 14),
          purpose: "顧客との打ち合わせ"
        )
      ]
    end

    def create_requests(organization, users)
      return organization.requests if organization.requests.any?

      leave = organization.request_types.find_by(code: "leave")
      expense = organization.request_types.find_by(code: "expense")

      submitted = organization.requests.create!(
        request_type: leave, applicant: users["sales1@demo.invalid"],
        title: "夏季休暇の取得", body: "8 月 12 日から 3 日間"
      )
      submitted.record_creation(actor: users["sales1@demo.invalid"])
      submitted.submit(actor: users["sales1@demo.invalid"])

      draft = organization.requests.create!(
        request_type: expense, applicant: users["dev1@demo.invalid"],
        title: "書籍購入の精算", body: "技術書 1 冊"
      )
      draft.record_creation(actor: users["dev1@demo.invalid"])

      [ submitted, draft ]
    end

    def create_documents(organization, users)
      return organization.documents if organization.documents.any?

      rules = organization.document_categories.find_by(code: "rules")
      manuals = organization.document_categories.find_by(code: "manuals")

      [
        organization.documents.create!(
          document_category: rules, author: users["admin@demo.invalid"],
          title: "就業規則（抜粋）", body: "始業は 9 時、終業は 18 時とします。",
          visibility: "organization"
        ),
        organization.documents.create!(
          document_category: manuals, author: users["dev1@demo.invalid"],
          title: "開発環境の準備手順", body: "リポジトリを取得し、コンテナを起動します。",
          visibility: "organization"
        )
      ]
    end
end
