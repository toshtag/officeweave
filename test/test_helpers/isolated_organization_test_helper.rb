# トランザクションで囲む既定を外したテストが使う、組織単位の作成と後片付け。
#
# 既定を外したテストは記録を確定させる。途中で終わると、それがそのまま残る。
# 残った組織は次の実行の作成を識別子の重複で失敗させ、以降はそのファイルの
# 全件が別の理由で崩れるため、最初の 1 件の理由が読めなくなる。
#
# 影響はそのファイルの中に収まらない。連番は fixture の読み込みのたびに
# fixture の最大 id へ戻る。残った記録がその次の値を占めていると、無関係な
# テストの採番が必ずそこへ当たり、主キーの衝突として現れる。
module IsolatedOrganizationTestHelper
  # 前の実行が残した記録を取り除いてから作る。
  def create_isolated_organization(name:, code:)
    discard_organization(Organization.find_by(code: code))

    Organization.create!(name: name, code: code)
  end

  # 組織と、その配下の記録を取り除く。
  #
  # 模型の破棄には記録を残す契約が入っており、失敗した実行のあとでは
  # 1 件でも残ると組織を消せない。読み込み済みの関連を使う破棄も、
  # そのあとに増えた記録を見ないため取りこぼす。
  #
  # ここでは契約ではなく掃除が目的であるため、参照の順に直接消す。
  def discard_organization(organization)
    return if organization.nil?

    ids = ScopedIds.new(organization)

    delete_dependent_records(ids)
    delete_owned_records(ids)

    User.where(id: ids.users).delete_all
    Organization.where(id: organization.id).delete_all
  end

  private
    # 組織を直接持たない記録。先に消さないと、持ち主の行を消せない。
    def delete_dependent_records(ids)
      Notification.where(user_id: ids.users).delete_all
      Notification.where(subject_type: "Request", subject_id: ids.requests).delete_all
      Notification.where(subject_type: "Announcement", subject_id: ids.announcements).delete_all
      RequestActivity.where(request_id: ids.requests).delete_all
      AnnouncementRead.where(user_id: ids.users).delete_all
      AnnouncementDepartment.where(announcement_id: ids.announcements).delete_all
      EventDepartment.where(event_id: ids.events).delete_all
      DocumentDepartment.where(document_id: ids.documents).delete_all
      WebhookDelivery.where(webhook_endpoint_id: ids.webhook_endpoints).delete_all
      Membership.where(user_id: ids.users).delete_all
      NotificationPreference.where(user_id: ids.users).delete_all
      Session.where(user_id: ids.users).delete_all
    end

    # 組織が持つ記録。部門は自己参照を持つが、1 文でまとめて消せば
    # 参照の検査は文の終わりに行われるため、上下の順は要らない。
    def delete_owned_records(ids)
      Request.where(id: ids.requests).delete_all
      RequestType.where(organization_id: ids.organization).delete_all
      Reservation.where(organization_id: ids.organization).delete_all
      Resource.where(organization_id: ids.organization).delete_all
      Event.where(id: ids.events).delete_all
      Announcement.where(id: ids.announcements).delete_all
      Document.where(id: ids.documents).delete_all
      DocumentCategory.where(organization_id: ids.organization).delete_all
      WebhookEndpoint.where(id: ids.webhook_endpoints).delete_all
      ApiToken.where(organization_id: ids.organization).delete_all
      AuditEvent.where(organization_id: ids.organization).delete_all
      Department.where(organization_id: ids.organization).delete_all
    end

    # 消す対象の id を、消し始める前に読み出しておく。
    # 途中で親を消すと、あとから子をたどれなくなる。
    class ScopedIds
      attr_reader :organization, :users, :requests, :announcements, :events, :documents,
                  :webhook_endpoints

      def initialize(organization)
        @organization = organization.id
        @users = User.where(organization_id: @organization).pluck(:id)
        @requests = Request.where(organization_id: @organization).pluck(:id)
        @announcements = Announcement.where(organization_id: @organization).pluck(:id)
        @events = Event.where(organization_id: @organization).pluck(:id)
        @documents = Document.where(organization_id: @organization).pluck(:id)
        @webhook_endpoints = WebhookEndpoint.where(organization_id: @organization).pluck(:id)
      end
    end
end
