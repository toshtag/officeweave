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
end
