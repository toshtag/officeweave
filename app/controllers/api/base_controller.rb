module Api
  # 外部からの接続の入口。
  #
  # 画面向けの認証とは別に扱う。
  # session に依存させると、外部からの接続で毎回ログイン画面へ送られる。
  class BaseController < ActionController::API
    # 受け取れない入力。呼び出す側が直せる誤りとして扱う。
    class InvalidParameter < StandardError
      attr_reader :parameter

      def initialize(parameter)
        @parameter = parameter
        super("#{parameter} is not a valid time")
      end
    end

    # 受け取る日時の年の範囲。
    #
    # Ruby は西暦 13 桁の年も解析する。そのまま問い合わせへ渡すと、
    # データベースが扱える範囲を超えて拒み、入力の誤りが 500 になる。
    # 判定は入口へ置き、データベースの限界を業務の経路へ持ち込まない。
    ACCEPTED_YEARS = (1000..9999)

    before_action :authenticate_with_token

    rescue_from InvalidParameter, with: :render_invalid_parameter

    private
      # 日時の入力を 1 か所で解釈する。
      #
      # 未指定は nil を返し、呼ぶ側が既定値を決める。解析できない値は
      # 既定値へ読み替えない。読み替えると、呼び出す側は誤りに気付かない
      # まま、意図と異なる結果を受け取る。
      #
      # 解析できない値は、nil が返る場合と例外になる場合の両方がある。
      # どちらも同じ誤りであるため、同じ扱いにそろえる。
      def time_param(name)
        value = params[name]
        return nil if value.blank?

        parsed = begin
          Time.zone.parse(value.to_s)
        rescue ArgumentError, TypeError
          nil
        end

        raise InvalidParameter, name if parsed.nil? || ACCEPTED_YEARS.exclude?(parsed.year)

        parsed
      end

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
