module Api
  module V1
    class UsersController < Api::BaseController
      # 利用者の一覧は管理者の token でだけ取得できる。
      before_action :require_administrator

      def index
        users = current_organization.users.ordered.includes(memberships: :department)

        render json: { users: users.map { |record| serialize(record) } }
      end

      private
        def require_administrator
          return if current_user.administrator?

          render json: { error: "forbidden" }, status: :forbidden
        end

        def serialize(user)
          {
            id: user.id,
            name: user.name,
            email_address: user.email_address,
            role: user.role,
            active: user.active?,
            department_ids: user.memberships.map(&:department_id)
          }
        end
    end
  end
end
