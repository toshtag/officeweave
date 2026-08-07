# 負荷測定用のデータ。
#
# 空のデータベースへ要求を投げても、応答の速さは分からない。一覧は並べる記録の
# 数で読み込む量が変わり、検索は対象の数で走査の量が変わる。測る前に、測るに
# 足る量を積む。
#
# 専用の組織へ積む。既にある組織と混ざると、測っている対象が分からなくなる。
#
# 何度実行しても同じ状態になるよう、識別できる値で対応づけて足りない分だけ作る。
# 消してから作り直す形にはしない。記録が残っている組織は消せないようにしてあり、
# 消すために依存を辿ると、その並びを間違えたときに他の組織へ影響し得る。
#
# 実在する個人や組織の情報は使わない。すべて架空の値とする。
class LoadSample
  ORGANIZATION = { name: "負荷測定用組織", code: "load-sample" }.freeze

  # 測るための利用者。一覧を開けるだけの権限を持たせる。
  EMAIL_ADDRESS = "measure@load-sample.invalid".freeze
  NAME = "測定 利用者".freeze

  # 1 度に書き込む行の数。
  #
  # 1 件ずつ作ると、記録の数だけ往復が出る。1 万件規模では、その往復が
  # 投入そのものの時間になる。既にある分は識別できる値で除いてから、
  # 足りない分だけをまとめて書き込む。
  INSERT_BATCH = 1_000

  # 1 人あたりに積む記録の数。
  #
  # 一覧の 1 ページ分（`Pagination::DEFAULT_PER_PAGE`）にそろえる。1 ページに
  # 収まる量では、読み込む量の違いが応答に現れない。
  PER_USER = Pagination::DEFAULT_PER_PAGE

  attr_reader :scale

  def initialize(scale: 20)
    @scale = Integer(scale)
  end

  def self.organization
    Organization.find_by(code: ORGANIZATION[:code])
  end

  def install
    ActiveRecord::Base.transaction do
      organization = find_or_create_organization
      department = organization.departments.find_or_create_by!(code: "measure") do |record|
        record.name = "測定部"
      end
      operator = create_operator(organization, department)
      users = create_users(organization, department)
      resources = create_resources(organization)
      request_type = create_request_type(organization, department)
      category = organization.document_categories.find_or_create_by!(code: "measure") do |record|
        record.name = "測定用の分類"
      end

      {
        "利用者" => users.size,
        "設備・備品" => resources.size,
        "お知らせ" => create_announcements(organization, users).size,
        "予定" => create_events(organization, users).size,
        "予約" => create_reservations(organization, users, resources).size,
        "申請" => create_requests(organization, users, request_type).size,
        "文書" => create_documents(organization, users, category).size,
        "監査記録" => create_audit_events(organization, users).size,
        "通知" => create_notifications(organization, operator).size
      }
    end
  end

  private
    def find_or_create_organization
      Organization.find_or_create_by!(code: ORGANIZATION[:code]) do |record|
        record.name = ORGANIZATION[:name]
      end
    end

    def create_operator(organization, department)
      user = find_or_create_user(organization, EMAIL_ADDRESS, name: NAME, role: "administrator")
      user.memberships.find_or_create_by!(department: department) { |record| record.primary = true }
      user
    end

    def create_users(organization, department)
      Array.new(scale) do |index|
        user = find_or_create_user(organization, "member#{index}@load-sample.invalid",
                                   name: "測定 #{index}", role: "member")
        user.memberships.find_or_create_by!(department: department) { |record| record.primary = true }
        user
      end
    end

    def find_or_create_user(organization, email_address, name:, role:)
      organization.users.find_or_create_by!(email_address: email_address) do |record|
        record.name = name
        record.role = role
        record.password = password
      end
    end

    def create_resources(organization)
      Array.new(scale) do |index|
        organization.resources.find_or_create_by!(code: "resource-#{index}") do |record|
          record.name = "測定用の設備 #{index}"
          record.capacity = index + 1
          record.position = index
        end
      end
    end

    def create_request_type(organization, department)
      request_type = organization.request_types.find_or_create_by!(code: "measure") do |record|
        record.name = "測定用の申請"
      end
      request_type.approval_steps.find_or_create_by!(position: 1) do |record|
        record.approver_department = department
      end
      request_type
    end

    def create_announcements(organization, users)
      insert_missing(organization.announcements, "測定用のお知らせ", users) do |author, index, now|
        { organization_id: organization.id, author_id: author.id,
          title: "測定用のお知らせ #{index}", body: body_for(index),
          visibility: "organization", published_at: now, created_at: now, updated_at: now }
      end
    end

    def create_events(organization, users)
      base = Time.current.beginning_of_hour

      insert_missing(organization.events, "測定用の予定", users) do |owner, index, now|
        start = base + index.hours

        { organization_id: organization.id, owner_id: owner.id,
          title: "測定用の予定 #{index}", starts_at: start, ends_at: start + 30.minutes,
          visibility: "organization", created_at: now, updated_at: now }
      end
    end

    def create_reservations(organization, users, resources)
      base = Time.current.beginning_of_hour

      insert_missing(organization.reservations, "測定用の用途", users, column: :purpose) do |reserver, index, now|
        # 時間帯を 1 件ずつ分ける。同じ設備の同じ時間帯は重ねられない。
        # 設備の数で割って詰めると、規模を変えたときに既にある予約とぶつかる。
        start = base + index.hours

        { organization_id: organization.id, resource_id: resources[index % resources.size].id,
          reserver_id: reserver.id, purpose: "測定用の用途 #{index}",
          starts_at: start, ends_at: start + 30.minutes, created_at: now, updated_at: now }
      end
    end

    def create_requests(organization, users, request_type)
      insert_missing(organization.requests, "測定用の申請", users) do |applicant, index, now|
        { organization_id: organization.id, request_type_id: request_type.id,
          applicant_id: applicant.id, title: "測定用の申請 #{index}", body: body_for(index),
          status: "pending", submitted_at: now, created_at: now, updated_at: now,
          decision_state_nonce: SecureRandom.uuid }
      end
    end

    def create_documents(organization, users, category)
      insert_missing(organization.documents, "測定用の文書", users) do |author, index, now|
        { organization_id: organization.id, author_id: author.id,
          document_category_id: category.id, title: "測定用の文書 #{index}",
          body: body_for(index), visibility: "organization", created_at: now, updated_at: now }
      end
    end

    # 足りない分だけをまとめて書き込む。
    #
    # 既にある分は、識別できる値から番号を読み取って除く。1 件ずつ存在を
    # 確かめると、記録の数だけ往復が出る。
    def insert_missing(association, prefix, users, column: :title)
      wanted = users.size * PER_USER
      existing = association.where(association.arel_table[column].matches("#{prefix} %"))
                            .pluck(column)
                            .filter_map { |value| value[/\d+\z/]&.to_i }
                            .to_set
      now = Time.current

      rows = (0...wanted).reject { |index| existing.include?(index) }
                         .map { |index| yield(users[index % users.size], index, now) }

      rows.each_slice(INSERT_BATCH) { |slice| association.klass.insert_all(slice) }

      Array.new(wanted)
    end

    # 監査記録と通知は、同じ内容を区別する識別子を持たない。
    # 足りない分だけ作る形にし、既にある分は数え直す。
    def create_audit_events(organization, users)
      wanted = users.size * PER_USER
      missing = wanted - organization.audit_events.count

      missing.clamp(0, wanted).times do |index|
        actor = users[index % users.size]

        organization.audit_events.create!(
          actor: actor, action: "user_created", target_type: "User", target_id: actor.id
        )
      end

      Array.new(wanted)
    end

    def create_notifications(organization, operator)
      announcements = organization.announcements.limit(PER_USER).to_a
      existing = operator.notifications.count

      announcements.drop(existing).each do |announcement|
        operator.notifications.create!(event: "announcement_published", subject: announcement)
      end

      announcements
    end

    # 利用者 1 人あたり PER_USER 件を作る。作り手を散らすのは、一覧が関連を
    # 1 件ずつ引く形になっていた場合に、それが応答へ現れるようにするためである。
    def each_record(users)
      (users.size * PER_USER).times.map do |index|
        yield(users[index % users.size], index)
      end
    end

    # 本文は一覧に出さないが、読み込む量には効く。実際の記録に近い長さにする。
    def body_for(index)
      "測定用の本文 #{index}。" * 40
    end

    def password
      # 測定のためだけに使う。人が使う経路の資格情報とは分ける。
      @password ||= ENV.fetch("LOAD_SAMPLE_PASSWORD", "load-sample-password")
    end
end
