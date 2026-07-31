module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
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
