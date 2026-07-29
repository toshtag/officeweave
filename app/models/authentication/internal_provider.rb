module Authentication
  # 利用者の記録に保存したパスワードで確かめる、既定の認証方式。
  class InternalProvider
    def self.name_key
      "internal"
    end

    # 資格情報から利用者を返す。該当しない場合は nil を返す。
    # 無効にされた利用者は、資格情報が正しくても認証しない。
    def self.authenticate(email_address:, password:)
      user = User.authenticate_by(email_address: email_address.to_s, password: password.to_s)

      user if user&.active?
    end

    # 画面でパスワードの入力を求めるかどうか。
    # 外部の方式では、入力欄そのものが不要になる場合がある。
    def self.password_required?
      true
    end
  end
end
