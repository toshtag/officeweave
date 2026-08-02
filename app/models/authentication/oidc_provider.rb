module Authentication
  # OIDC を使う設定。
  #
  # 資格情報はこの製品の中に無い。この方式では、認可サーバーへの転送と
  # 受け取りで利用者を決める。差し替え口の 3 つの呼び出しのうち、
  # authenticate は使わない。
  class OidcProvider
    def self.name_key = "oidc"

    # パスワードの入力欄も、変更や再設定の経路も出さない。
    def self.password_required? = false

    # 資格情報からは認証しない。
    #
    # 常に nil を返す。ログインの経路（/oidc/session）を通らない要求で、
    # 利用者が決まることはない。
    def self.authenticate(email_address:, password:) = nil
  end
end
