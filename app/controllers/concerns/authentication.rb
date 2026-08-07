module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?, :password_credentials?
  end

  class_methods do
    # 認証を要さない入口。公開する理由を必ず書く。
    #
    # 既定は認証を要する。開く側だけが宣言する形にすると、開いた入口の数は
    # 少なく保てるが、なぜ開いているのかは宣言からは読めない。理由を書かせる
    # ことで、次に読む人が判断をやり直せる。
    #
    # 返してよい情報も理由へ書く。認証を要さない入口は、誰でも到達できる。
    def allow_unauthenticated_access(reason:, **options)
      raise ArgumentError, "認証を要さない理由を書く" if reason.to_s.strip.empty?

      unauthenticated_access[:reason] = reason
      unauthenticated_access[:only] = Array(options[:only]).map(&:to_s).presence

      skip_before_action :require_authentication, **options
    end

    # 開いている入口とその理由。宣言が無ければ空を返す。
    def unauthenticated_access
      @unauthenticated_access ||= {}
    end

    # その動作が認証を要さないか。要する場合は nil を返す。
    def unauthenticated_reason(action)
      return nil if unauthenticated_access.empty?

      only = unauthenticated_access[:only]

      unauthenticated_access[:reason] if only.nil? || only.include?(action.to_s)
    end
  end

  private
    def authenticated?
      resume_session
    end

    # 稼働中の認証方式。設定で差し替えられる。
    def authentication_provider
      Authentication::ProviderRegistry.current
    end

    # この製品の中に、変更できる資格情報があるか。
    #
    # 外部の方式へ切り替えた環境では、パスワードはこの製品の外にある。
    # 入力欄も、変更の経路も、案内も出さない。
    def password_credentials?
      authentication_provider.password_required?
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      # 署名の検証に失敗した値も後片付けの対象にする。
      # signed から読むと nil になり、壊れた Cookie が残ったままになる。
      return nil if cookies[:session_id].blank?

      session = Session.includes(:user).find_by(id: cookies.signed[:session_id])
      return discard_session(session) unless usable_session?(session)

      session.record_activity!
      session
    end

    def usable_session?(session)
      return false if session.nil?

      # 無効化された利用者のセッションは、残っていても認証済みとして扱わない。
      return false unless session.user&.active?

      session.active?
    end

    # 認証へ使えないセッションは、記録も Cookie も残さない。
    # 記録だけ消すと期限切れの Cookie が端末に残り、Cookie だけ消すと
    # 期限を過ぎた記録が保持された値から再び引き当てられる。
    def discard_session(session)
      session&.destroy
      cookies.delete(:session_id, path: "/")
      nil
    end

    # 保存するのは、検査を通ったパスとクエリだけとする。
    # request.url はスキームとホストを含む。要求の Host を戻り先へ持ち込まない。
    def request_authentication
      session[:return_to_after_authenticating] = LocalPath.permitted(request.fullpath)
      redirect_to new_session_path
    end

    # 保存済みの値も、使用する時点でもう一度検査する。
    # 落とす先は root_path とする。root_url は要求の Host を再び含める。
    def after_authentication_url
      LocalPath.permitted(session.delete(:return_to_after_authenticating)) || root_path
    end

    def start_new_session_for(user)
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session

        # 有効期限は記録側の絶対期限と一致させる。permanent は使わない。
        # 端末に残る期間と、認証へ使える期間が食い違う状態を作らない。
        cookies.signed[:session_id] = {
          value: session.id,
          expires: session.expires_at,
          httponly: true,
          same_site: :lax,
          secure: request.ssl?,
          path: "/"
        }
      end
    end

    def terminate_session
      # 記録が並行して消えていても失敗させない。ログアウトは常に成立させる。
      Current.session&.destroy
      Current.session = nil
      cookies.delete(:session_id, path: "/")
    end
end
