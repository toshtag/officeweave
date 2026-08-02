module Api
  # 外部からの接続の入口。
  #
  # 画面向けの認証とは別に扱う。
  # session に依存させると、外部からの接続で毎回ログイン画面へ送られる。
  class BaseController < ActionController::API
    include TimeParameters

    # 配信する内容の出所の制限は付けない。
    #
    # 方針はブラウザーが文書を読み込むときに効く。応答は JSON であり、
    # 読み込む相手は呼び出す側のプログラムである。すべての応答へ付けても、
    # 守るものが増えず、量だけが増える。
    #
    # ActionController::API は方針の仕組みを持たない。外すために取り込む。
    include ActionController::ContentSecurityPolicy
    content_security_policy false

    # 1 つの token が一定の時間に送れる要求の数。
    #
    # 外部からの接続は、画面の操作と違って待たずに繰り返せる。上限が無いと、
    # 1 つの token で読み込みを占有できる。
    REQUESTS_PER_MINUTE = 300

    before_action :authenticate_with_token
    before_action :authorize_scope

    # 数えるのは token ごととする。要求元のアドレスで数えると、同じ経路の
    # 別の token まで巻き込む。認証の後へ置き、値が違う要求は 401 のままとする。
    rate_limit to: REQUESTS_PER_MINUTE, within: 1.minute,
               by: -> { @api_token&.id || request.remote_ip },
               with: -> { render json: { error: "rate_limited" }, status: :too_many_requests },
               store: RateLimitStore

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

      # token が許可された範囲かを確かめる。
      #
      # 判定は認証の後に行う。値が違う場合は、範囲の話をする前に 401 とする。
      #
      # 範囲の名前は制御部の名前から決める。経路ごとに書くと、資源を足した
      # ときに書き忘れた経路が、すべての token へ開く。
      def authorize_scope
        scope = controller_name

        return if @api_token.permits?(scope)

        # どの範囲が足りないのかを示す。呼び出す側が、発行し直す判断をできる。
        render json: { error: "forbidden_scope", scope: scope }, status: :forbidden
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

      # 一覧の応答を、1 ページ分と目安の情報で組み立てる。
      #
      # 上限は画面と同じ仕組み（Pagination）へ委ねる。要求で件数を指定できる
      # ため、際限なく大きな値を渡されても読む量が決まる必要がある。
      def paginated(scope)
        Pagination.new(scope, page: params[:page], per_page: params[:per_page] || Pagination::DEFAULT_PER_PAGE)
      end

      # 呼び出す側が、次のページがあるかどうかを判断できるようにする。
      def pagination_meta(page)
        {
          page: page.current_page,
          per_page: page.per_page,
          total_count: page.total_count,
          total_pages: page.total_pages
        }
      end
  end
end
