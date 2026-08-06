require "test_helper"

# 申請の流れが作る通知。
#
# 発生の単位が正しく組み立てられているかを、模型ではなく実際の流れで
# 確かめる。単位の値そのものではなく、利用者から見た結果を見る。
class RequestNotificationTest < ActiveSupport::TestCase
  setup do
    @organization = organizations(:main)
    @applicant = users(:taro)
    @approver = users(:approver)
    Notification.delete_all
  end

  test "差し戻したあとの再提出で、承認者に新しい未読が作られる" do
    request = submit_new_request

    assert_equal 1, approver_unread.count

    request.return_to_applicant(actor: @approver, comment: "書き直してください")
    read_everything
    request.reload.submit(actor: @applicant)

    assert_equal 1, approver_unread.count, "再提出で新しい未読が作られていない"
  end

  test "差し戻しは申請者へ知らせる" do
    request = submit_new_request
    request.return_to_applicant(actor: @approver, comment: nil)

    assert_equal 1, unread_for(@applicant, "request_returned").count
  end

  test "同じ利用者が複数の段を担当する場合、それぞれの段で作られる" do
    request = submit_to_two_step_route

    assert_equal 1, approver_unread.count

    read_everything
    request.approve(actor: @approver)

    assert_equal 1, approver_unread.count, "2 つ目の段で未読が作られていない"
  end

  test "同じ決裁をやり直しても通知は増えない" do
    request = submit_new_request
    activity = request.request_activities.order(:id).last

    # 同じ発生を表す値で二度呼ぶ。ジョブのやり直しはこの形になる。
    2.times do
      Notification.deliver_to_all(users: [ @approver ], subject: request,
                                  event: "request_submitted", occurrence: "activity:#{activity.id}")
    end

    assert_equal 1, Notification.where(subject: request, user: @approver).count
  end

  test "提出の通知は、その提出の履歴を発生として持つ" do
    request = submit_new_request
    activity = request.request_activities.where(action: "submitted").sole

    assert_equal "activity:#{activity.id}", approver_unread.sole.occurrence
  end

  private
    def approver_unread = unread_for(@approver, "request_submitted")

    def unread_for(user, event)
      Notification.where(user: user, event: event).unread
    end

    def read_everything
      Notification.update_all(read_at: Time.current)
    end

    def submit_new_request
      request = @organization.requests.create!(
        applicant: @applicant, request_type: request_types(:leave),
        title: "休暇の申請", body: "私用のため"
      )
      request.submit(actor: @applicant)
      request
    end

    # 同じ承認者が 2 つの段を担当する経路を作る。
    def submit_to_two_step_route
      type = @organization.request_types.create!(name: "二段の申請", code: "two-step")
      2.times do |index|
        type.approval_steps.create!(position: index + 1, approver_department: departments(:sales))
      end

      request = @organization.requests.create!(
        applicant: @applicant, request_type: type, title: "二段の申請", body: "確認"
      )
      request.submit(actor: @applicant)
      request
    end
end
