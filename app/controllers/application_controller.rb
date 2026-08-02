class ApplicationController < ActionController::Base
  include Authentication
  include Localizable
  include Authorization
  include Auditable
  include TimeParameters

  # 対象は、webp、CSS の入れ子、CSS の :has に対応した版とする。
  allow_browser versions: :modern

  private
    # 操作の対象は、常にログイン中の利用者が属する組織へ限定する。
    # 識別子を受け取って引き当てると、別組織の記録へ到達できてしまう。
    def current_organization
      Current.user&.organization
    end
    helper_method :current_organization

    # 要求の記録へ、誰のどの組織の要求かを残す。
    #
    # 記録を出す側（config/initializers/logging.rb）は、利用者の特定の
    # 仕組みを知らない。識別子だけを渡す。名前とメールアドレスは渡さない。
    def append_info_to_payload(payload)
      super

      payload[:user_id] = Current.user&.id
      payload[:organization_id] = Current.user&.organization_id
    end
end
