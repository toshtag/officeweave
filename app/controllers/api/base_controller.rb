module Api
  # 外部からの接続の入口。
  #
  # 画面向けの認証とは別に扱う。
  # session に依存させると、外部からの接続で毎回ログイン画面へ送られる。
  class BaseController < ActionController::API
    include TimeParameters

    before_action :authenticate_with_token

    rescue_from InvalidParameter, with: :render_invalid_parameter

    private
      # 誤った値そのものは返さない。呼び出す側は自分が送った値を知っており、
      # 送り返す利点がない。
      def render_invalid_parameter(error)
        render json: { error: "invalid_parameter", parameter: error.parameter }, status: :bad_request
      end

      def authenticate_with_token
        @api_token = ApiToken.authenticate(bearer_token)

        return if @api_token

        # 認証方式を示し、呼び出す側が対処できるようにする。
        headers["WWW-Authenticate"] = %(Bearer realm="OfficeWeave")
        render json: { error: "unauthorized" }, status: :unauthorized
      end

      def bearer_token
        pattern = /\ABearer /
        header = request.headers["Authorization"].to_s

        header.sub(pattern, "") if header.match?(pattern)
      end

      def current_user
        @api_token.user
      end

      def current_organization
        @api_token.organization
      end
  end
end
