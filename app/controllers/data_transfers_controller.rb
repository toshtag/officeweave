# 利用者と部門の入出力。
#
# 取り込みは既存の記録を書き換えるため、管理者へ限定する。
class DataTransfersController < ApplicationController
  before_action :require_administrator

  def show
  end

  def users_export
    record_audit_event("users_exported")

    send_data UserCsv.new(current_organization).export,
              filename: "users-#{Date.current.iso8601}.csv",
              type: "text/csv; charset=utf-8"
  end

  def departments_export
    record_audit_event("departments_exported")

    send_data DepartmentCsv.new(current_organization).export,
              filename: "departments-#{Date.current.iso8601}.csv",
              type: "text/csv; charset=utf-8"
  end

  def users_import
    import(UserCsv, "users_imported")
  end

  def departments_import
    import(DepartmentCsv, "departments_imported")
  end

  private
    # 取り込みの流れは、対象が変わっても同じである。
    # 経路ごとに書くと、片方だけが記録を残す形になり得る。
    def import(transfer, action)
      file = params[:file]

      if file.blank?
        return redirect_to data_transfers_path, alert: t("data_transfers.no_file")
      end

      @result = transfer.new(current_organization).import(file.read)

      if @result.success?
        record_audit_event(action,
                           details: { created: @result.created_count, updated: @result.updated_count })
        redirect_to data_transfers_path,
                    notice: t("data_transfers.imported", created: @result.created_count,
                                                         updated: @result.updated_count)
      else
        render :show, status: :unprocessable_content
      end
    end
end
