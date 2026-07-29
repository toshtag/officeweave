require "application_system_test_case"

class HealthTest < ApplicationSystemTestCase
  test "稼働確認の画面へ到達できる" do
    visit rails_health_check_path

    assert_equal 200, page.status_code
  end
end
