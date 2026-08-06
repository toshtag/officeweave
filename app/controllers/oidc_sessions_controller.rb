# OIDC でのログイン。
#
# 認可サーバーへ転送し、戻ってきた code を id_token へ交換して、
# この製品の利用者へ結び付ける。
#
# 利用者は自動で作らない。作ると、認可サーバーへ登録された相手が、
# この製品の組織へそのまま入れる。
class OidcSessionsController < ApplicationController
  records_audit :create

  allow_unauthenticated_access
  before_action :require_oidc

  # 認可を開始する。
  #
  # 状態を変えるため GET では受け付けない。GET で始められると、
  # 別の画面から貼った経路で認可の要求を起こせる。
  def create
    state = SecureRandom.urlsafe_base64(24)
    nonce = SecureRandom.urlsafe_base64(24)
    verifier = SecureRandom.urlsafe_base64(48)

    # 要求と応答の対応は、この端末のセッションだけが知っている値で確かめる。
    session[:oidc] = { "state" => state, "nonce" => nonce, "verifier" => verifier }

    redirect_to client.authorization_url(
      redirect_uri: oidc_callback_url, state: state, nonce: nonce,
      code_challenge: challenge_for(verifier)
    ), allow_other_host: true
  rescue Authentication::Oidc::Client::ProviderError => error
    reject(error.message)
  end

  # 認可サーバーからの戻り。
  #
  # 開始のときに保持した値を、使ったらすぐ捨てる。残すと、同じ state で
  # 二度目の受け取りができる。
  def callback
    started = session.delete(:oidc)

    return reject("認可の開始を確認できません") if started.blank?
    return reject("state が一致しません") unless matches_state?(started["state"])
    return reject("認可サーバーが拒否しました") if params[:code].blank?

    claims = verified_claims(started, params[:code])
    user = User.find_by(email_address: claims.email_address)

    # 利用者を特定できない失敗は、どの組織の記録にもならない。
    # 内部認証の失敗と同じ扱いとし、記録は残さない。
    return reject("該当する利用者がいません") if user.nil?
    return reject("利用者が無効化されています", user: user) unless user.active?

    start_new_session_for(user)
    record_audit_event("signed_in", organization: user.organization, actor: user,
                                    target: user, details: { provider: provider_name })

    redirect_to after_authentication_url
  rescue Authentication::Oidc::Client::ProviderError, Authentication::Oidc::IdToken::InvalidIdToken => error
    reject(error.message)
  end

  private
    def require_oidc
      # 設定が無い環境では、この経路そのものを無いものとして扱う。
      head :not_found unless Authentication::Oidc.configured?
    end

    def client = @client ||= Authentication::Oidc.client

    def provider_name = Authentication::OidcProvider.name_key

    # PKCE の検証用の値。送るのは要約だけとする。
    def challenge_for(verifier)
      Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(verifier), padding: false)
    end

    def matches_state?(expected)
      given = params[:state].to_s

      given.present? && ActiveSupport::SecurityUtils.secure_compare(given, expected.to_s)
    end

    def verified_claims(started, code)
      id_token = client.exchange_code(
        code: code, redirect_uri: oidc_callback_url, code_verifier: started.fetch("verifier")
      )

      Authentication::Oidc::IdToken.verify(
        id_token, jwks: client.jwks, issuer: Authentication::Oidc.settings.issuer,
        client_id: Authentication::Oidc.settings.client_id, nonce: started.fetch("nonce")
      )
    end

    # 失敗の理由は、組織が分かる場合だけ記録へ残す。画面へは同じ文面を返す。
    #
    # 画面へ理由を出すと、利用者が居るかどうかや、認可サーバーの構成を
    # 外から読み取れる。
    def reject(reason, user: nil)
      if user
        record_audit_event("sign_in_failed", organization: user.organization, actor: nil, target: user,
                                             details: { provider: provider_name, reason: reason })
      end

      redirect_to new_session_path, alert: t("sessions.oidc.failed")
    end
end
