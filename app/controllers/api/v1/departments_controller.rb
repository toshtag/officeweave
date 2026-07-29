module Api
  module V1
    class DepartmentsController < Api::BaseController
      def index
        departments = current_organization.departments.ordered.includes(:parent)

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
