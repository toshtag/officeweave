# 運用時の稼働確認に使う。
#
# /up はアプリケーションが例外なく起動できたかだけを返す。
# 実際の障害はデータベースへ到達できない形で現れることが多いため、
# 依存先まで確認した結果をここで返す。
#
# 認証を導入した後も、このエンドポイントは認証を要求しない。
# 監視側が資格情報を持たずに到達できる必要がある。
class HealthController < ApplicationController
  # 監視側が資格情報を持たずに到達できる必要がある。
  allow_unauthenticated_access

  def show
    checks = { database: database_status }
    healthy = checks.values.all?("ok")

    render json: {
      status: healthy ? "ok" : "error",
      checks: checks,
      checked_at: Time.current.iso8601
    }, status: healthy ? :ok : :service_unavailable
  end

  private
    def database_status
      ActiveRecord::Base.connection.select_value("SELECT 1")
      "ok"
    rescue StandardError
      "error"
    end
end
