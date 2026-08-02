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
    checks = {
      database: database_status,
      queue: queue_status,
      storage: storage_status
    }
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

    # ジョブの保存先。
    #
    # 到達できないと、画面は開けてもメールと Webhook を積めない。
    # 積めない要求は、その場で失敗する。
    def queue_status
      SolidQueue::Job.connection.select_value("SELECT 1")
      "ok"
    rescue StandardError
      "error"
    end

    # 添付ファイルの保存先。
    #
    # 書けないと、文書へ添付する操作がその場で失敗する。
    #
    # 実際に書いて確かめない。稼働確認は監視から繰り返し呼ばれるため、
    # 1 回ごとにファイルを作ると、監視の間隔がそのまま書き込みの回数になる。
    # 書き込みまで含めた確認は bin/diagnose が行う。
    def storage_status
      root = ActiveStorage::Blob.service.try(:root)

      # ローカルディスク以外の保存先は、ここでは判定しない。
      return "ok" if root.blank?

      File.writable?(root.to_s) ? "ok" : "error"
    rescue StandardError
      "error"
    end
end
