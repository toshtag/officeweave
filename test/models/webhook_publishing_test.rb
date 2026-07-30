require "test_helper"

class WebhookPublishingTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.com/hook")
  end

  test "申請の提出で送信が積まれる" do
    assert_enqueued_with(job: DeliverWebhookJob) do
      requests(:hanako_leave_draft).submit(actor: users(:hanako))
    end
  end

  test "承認で送信が積まれる" do
    assert_enqueued_with(job: DeliverWebhookJob) do
      requests(:hanako_expense_pending).approve(actor: users(:taro))
    end
  end

  test "停止中の送信先へは積まれない" do
    @endpoint.update!(active: false)

    assert_no_enqueued_jobs(only: DeliverWebhookJob) do
      requests(:hanako_leave_draft).submit(actor: users(:hanako))
    end
  end

  test "別組織の送信先へは積まれない" do
    other = organizations(:other).webhook_endpoints.create!(name: "別組織", url: "https://hooks.example.com/hook")

    perform_enqueued_jobs_ids = []
    assert_enqueued_jobs 1, only: DeliverWebhookJob do
      requests(:hanako_leave_draft).submit(actor: users(:hanako))
    end

    assert_not_nil other
    assert_empty perform_enqueued_jobs_ids
  end

  test "許可されない遷移では積まれない" do
    assert_no_enqueued_jobs(only: DeliverWebhookJob) do
      requests(:hanako_leave_draft).approve(actor: users(:taro))
    end
  end
end
