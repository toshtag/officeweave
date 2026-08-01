require "test_helper"

# 組織をまたぐ参照を拒むことを、模型を横断して 1 か所で確かめる。
#
# 同じ不変条件が模型ごとに分かれていると、追加した模型で欠けても気付けない。
# 実際、予約の予定と予約者はこの観点が抜けたまま残っていた（#58）。
class OrganizationBoundaryTest < ActiveSupport::TestCase
  setup do
    @main = organizations(:main)
    @insider = users(:hanako)
    @outsider = users(:outsider)
    @other_department = departments(:other_general)
  end

  test "別組織の利用者はお知らせの作成者に指定できない" do
    announcement = @main.announcements.new(title: "件名", body: "本文",
                                           visibility: "organization", author: @outsider)

    assert_not announcement.valid?
    assert_includes announcement.errors.details[:author], { error: :different_organization }
  end

  test "別組織の利用者は予定の持ち主に指定できない" do
    event = @main.events.new(title: "件名", starts_at: 1.day.from_now, ends_at: 2.days.from_now,
                             visibility: "organization", owner: @outsider)

    assert_not event.valid?
    assert_includes event.errors.details[:owner], { error: :different_organization }
  end

  test "別組織の利用者は文書の作成者に指定できない" do
    document = @main.documents.new(title: "件名", visibility: "organization", author: @outsider)

    assert_not document.valid?
    assert_includes document.errors.details[:author], { error: :different_organization }
  end

  test "別組織の利用者は申請者に指定できない" do
    request = @main.requests.new(title: "件名", status: "draft",
                                 request_type: request_types(:leave), applicant: @outsider)

    assert_not request.valid?
    assert_includes request.errors.details[:applicant], { error: :different_organization }
  end

  test "別組織の利用者へ token を発行できない" do
    token = @main.api_tokens.new(name: "連携", user: @outsider)

    assert_not token.valid?
    assert_includes token.errors.details[:user], { error: :different_organization }
  end

  test "別組織の利用者は監査記録の実行者に指定できない" do
    audit_event = AuditEvent.new(organization: @main, action: "user_created", actor: @outsider)

    assert_not audit_event.valid?
    assert_includes audit_event.errors.details[:actor], { error: :different_organization }
  end

  test "実行者を持たない監査記録は従来どおり作れる" do
    audit_event = AuditEvent.new(organization: @main, action: "user_created")

    assert_predicate audit_event, :valid?
  end

  test "別組織の利用者はお知らせの既読に記録できない" do
    read = AnnouncementRead.new(announcement: announcements(:company_wide),
                                user: @outsider, read_at: Time.current)

    assert_not read.valid?
    assert_includes read.errors.details[:user], { error: :different_organization }
  end

  test "別組織の利用者は申請の履歴の実行者に指定できない" do
    activity = RequestActivity.new(request: requests(:hanako_expense_pending),
                                   actor: @outsider, action: "created")

    assert_not activity.valid?
    assert_includes activity.errors.details[:actor], { error: :different_organization }
  end

  test "別組織の利用者へは通知を作れない" do
    notification = Notification.new(user: @outsider, subject: announcements(:company_wide),
                                    event: "announcement_published")

    assert_not notification.valid?
    assert_includes notification.errors.details[:user], { error: :different_organization }
  end

  test "別組織の部門はお知らせの公開先に結び付けられない" do
    link = AnnouncementDepartment.new(announcement: announcements(:company_wide),
                                      department: @other_department)

    assert_not link.valid?
    assert_includes link.errors.details[:department], { error: :different_organization }
  end

  test "別組織の部門は予定の公開先に結び付けられない" do
    link = EventDepartment.new(event: events(:company_meeting), department: @other_department)

    assert_not link.valid?
    assert_includes link.errors.details[:department], { error: :different_organization }
  end

  test "別組織の部門は文書の参照先に結び付けられない" do
    link = DocumentDepartment.new(document: documents(:travel_rule), department: @other_department)

    assert_not link.valid?
    assert_includes link.errors.details[:department], { error: :different_organization }
  end

  test "同じ組織の記録は従来どおり作れる" do
    assert_predicate @main.announcements.new(title: "件名", body: "本文",
                                             visibility: "organization", author: @insider), :valid?
    assert_predicate @main.events.new(title: "件名", starts_at: 1.day.from_now, ends_at: 2.days.from_now,
                                      visibility: "organization", owner: @insider), :valid?
    assert_predicate @main.documents.new(title: "件名", visibility: "organization",
                                         author: @insider), :valid?
    assert_predicate @main.requests.new(title: "件名", status: "draft",
                                        request_type: request_types(:leave), applicant: @insider), :valid?
    assert_predicate @main.api_tokens.new(name: "連携", user: @insider), :valid?
    assert_predicate AuditEvent.new(organization: @main, action: "user_created", actor: @insider), :valid?
    assert_predicate AnnouncementRead.new(announcement: announcements(:company_wide),
                                          user: @insider, read_at: Time.current), :valid?
    assert_predicate RequestActivity.new(request: requests(:hanako_expense_pending),
                                         actor: @insider, action: "created"), :valid?
    assert_predicate Notification.new(user: @insider, subject: announcements(:company_wide),
                                      event: "announcement_published"), :valid?
    assert_predicate AnnouncementDepartment.new(announcement: announcements(:company_wide),
                                                department: departments(:sales)), :valid?
    assert_predicate EventDepartment.new(event: events(:company_meeting),
                                         department: departments(:sales)), :valid?
    assert_predicate DocumentDepartment.new(document: documents(:travel_rule),
                                            department: departments(:sales)), :valid?
  end
end
