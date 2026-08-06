require "test_helper"

# 増え続ける記録の後始末。
#
# 通知は利用者ごとに、送信の記録は試行ごとに増える。運用の通知も日ごとに
# 増える。どれも放っておくと溜まるだけであり、消す判断を誰も持っていない
# 状態になる。
#
# 既定は「消さない」とする。既定で消す形にすると、この版へ入れ替えただけで
# 過去の記録が消える組織が出る。
class RecordRetentionTest < ActiveSupport::TestCase
  RETENTION = {
    Notification => Officeweave::Configuration::NotificationRetention,
    WebhookDelivery => Officeweave::Configuration::WebhookDeliveryRetention,
    OperationalAlert => Officeweave::Configuration::OperationalAlertRetention
  }.freeze

  test "指定が無ければ 1 件も消さない" do
    RETENTION.each_key do |model|
      create_record(model, at: 10.years.ago)

      with_days(model, nil) { assert_equal 0, model.delete_expired, model.name }
    end
  end

  test "指定した日数より古い記録を消す" do
    RETENTION.each_key do |model|
      create_record(model, at: 40.days.ago)

      with_days(model, 30) { assert_equal 1, model.delete_expired, model.name }
    end
  end

  test "指定した日数の内側にある記録は残す" do
    RETENTION.each_key do |model|
      create_record(model, at: 10.days.ago)

      with_days(model, 30) { assert_equal 0, model.delete_expired, model.name }
    end
  end

  test "境界の時刻ちょうどは残す側に入れる" do
    # 指定した日数は「残す期間」であり、その端は残す側に入る。監査記録と
    # 同じ数え方にする。片方だけ違うと、運用者が日数の意味を 2 通り覚える。
    at = Time.current

    RETENTION.each_key do |model|
      create_record(model, at: at - 30.days)

      with_days(model, 30) { assert_equal 0, model.delete_expired(at: at), model.name }
    end
  end

  test "空文字と未設定はどちらも消さないとして扱う" do
    RETENTION.each_value do |configuration|
      assert_nil configuration.resolve(nil), configuration.name
      assert_nil configuration.resolve(""), configuration.name
    end
  end

  test "読み取れない値は起動の時点で拒む" do
    RETENTION.each_value do |configuration|
      [ "0", "-1", "007", "30日", "abc", "1.5" ].each do |raw|
        assert_raises(ArgumentError, "#{configuration.name} が #{raw.inspect} を受け入れた") do
          configuration.resolve(raw)
        end
      end
    end
  end

  test "後始末が定期実行へ登録されている" do
    schedule = YAML.safe_load_file(Rails.root.join("config/recurring.yml"), aliases: true).fetch("production")
    commands = schedule.values.filter_map { |task| task["command"] }

    RETENTION.each_key do |model|
      assert_includes commands, "#{model.name}.delete_expired"
    end
  end

  private
    # 実行環境の値そのものを差し替える。読み取りの経路ごと確かめるため、
    # 日数を返す処理を置き換えない。
    def with_days(model, days)
      variable = RETENTION.fetch(model)::VARIABLE
      original = ENV[variable]
      ENV[variable] = days&.to_s
      yield
    ensure
      ENV[variable] = original
    end

    def create_record(model, at:)
      case model.name
      when "Notification"
        Notification.create!(user: users(:taro), subject: requests(:taro_leave_pending),
                             event: "request_submitted", occurrence: "retention", created_at: at)
      when "WebhookDelivery"
        endpoint = organizations(:main).webhook_endpoints.create!(
          name: "保持の確認", url: "https://example.com/hook", secret: "a-long-enough-secret"
        )
        endpoint.webhook_deliveries.create!(event: "request_submitted", created_at: at)
      when "OperationalAlert"
        OperationalAlert.create!(occurrence: "retention", sent_at: at, created_at: at)
      end
    end
end
