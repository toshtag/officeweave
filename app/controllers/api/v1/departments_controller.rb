module Api
  module V1
    class DepartmentsController < Api::BaseController
      def index
        # 階層は 1 回の問い合わせで組み立てる。includes(:parent) は 1 段目しか
        # 先読みしないため、2 段目より上がそのまま問い合わせになる。
        departments = Department.with_ancestors(current_organization.departments.ordered)

        render json: { departments: departments.map { |record| serialize(record) } }
      end

      private
        def serialize(department)
          {
            id: department.id,
            name: department.name,
            code: department.code,
            parent_id: department.parent_id,
            path: department.display_path
          }
        end
    end
  end
end
