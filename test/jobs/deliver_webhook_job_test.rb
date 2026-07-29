require "test_helper"

class DeliverWebhookJobTest < ActiveJob::TestCase
  setup do
    @endpoint = organizations(:main).webhook_endpoints.create!(name: "連携先", url: "https://example.invalid/hook")
  end

  test "宛先へ到達できない場合も記録が残る" do
    assert_difference -> { WebhookDelivery.count }, 1 do
      DeliverWebhookJob.perform_now(@endpoint.id, "request_submitted", { subject_id: 1 })
    end

    delivery = @endpoint.webhook_deliveries.recent_first.first

    assert_not_predicate delivery, :succeeded?
    assert delivery.error_message.present?
  end

  test "停止中の送信先へは送らない" do
    @endpoint.update!(active: false)

    assert_no_difference -> { WebhookDelivery.count } do
      DeliverWebhookJob.perform_now(@endpoint.id, "request_submitted", { subject_id: 1 })
    end
  end

  test "存在しない送信先でも失敗しない" do
    assert_nothing_raised do
      DeliverWebhookJob.perform_now(0, "request_submitted", { subject_id: 1 })
    end
  end
end
