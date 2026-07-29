class ApplicationController < ActionController::Base
  include Authentication
  include Localizable
  include Authorization
  include Auditable

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private
    # 操作の対象は、常にログイン中の利用者が属する組織へ限定する。
    # 識別子を受け取って引き当てると、別組織の記録へ到達できてしまう。
    def current_organization
      Current.user&.organization
    end
    helper_method :current_organization
end
