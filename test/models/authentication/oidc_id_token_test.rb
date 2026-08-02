require "test_helper"
require "jwt"

module Authentication
  # OIDC の id_token の検証。
  #
  # ここを通った id_token は、そのままログインの根拠になる。検証の抜けは、
  # 誰でも任意の利用者としてログインできることに等しい。
  #
  # 鍵は実行のたびに作る。固定した鍵を置くと、その鍵で署名した token が
  # リポジトリの外でも作れる。
  class OidcIdTokenTest < ActiveSupport::TestCase
    ISSUER = "https://idp.example.com".freeze
    CLIENT_ID = "officeweave".freeze
    NONCE = "a-request-nonce".freeze
    KEY_ID = "test-key".freeze

    test "正しい id_token から要求を取り出せる" do
      claims = verify(encode)

      assert_equal "person@example.com", claims.email_address
      assert_equal "subject-1", claims.subject
    end

    test "署名が別の鍵のものは受け付けない" do
      other = OpenSSL::PKey::RSA.generate(2048)

      assert_rejected encode(key: other)
    end

    test "署名の無い id_token は受け付けない" do
      # alg=none を受け入れると、誰でも中身を作れる。
      unsigned = JWT.encode(payload, nil, "none")

      assert_rejected unsigned
    end

    test "共通鍵の方式へすり替えた id_token は受け付けない" do
      # 公開鍵を共通鍵として使う古い攻撃を塞ぐ。
      forged = JWT.encode(payload, jwk_public_key_material, "HS256", kid: KEY_ID)

      assert_rejected forged
    end

    test "発行者が違うものは受け付けない" do
      assert_rejected encode(claims: { iss: "https://attacker.example.com" })
    end

    test "宛先が違うものは受け付けない" do
      assert_rejected encode(claims: { aud: "another-client" })
    end

    test "宛先の一覧に自分が含まれていれば受け付ける" do
      claims = verify(encode(claims: { aud: [ "another-client", CLIENT_ID ] }))

      assert_equal "person@example.com", claims.email_address
    end

    test "期限を過ぎたものは受け付けない" do
      assert_rejected encode(claims: { exp: 1.minute.ago.to_i })
    end

    test "未来に発行されたものは受け付けない" do
      # 時計のずれを吸収する余裕は持つが、限度を超えたものは受け付けない。
      assert_rejected encode(claims: { iat: 10.minutes.from_now.to_i })
    end

    test "要求した nonce と違うものは受け付けない" do
      # 別の要求への応答を持ち込ませない。
      assert_rejected encode(claims: { nonce: "another-nonce" })
    end

    test "nonce を持たないものは受け付けない" do
      assert_rejected encode(claims: { nonce: nil })
    end

    test "利用者を特定できないものは受け付けない" do
      assert_rejected encode(claims: { email: nil })
      assert_rejected encode(claims: { sub: nil })
    end

    test "確認されていないメールアドレスは受け付けない" do
      # 確認していないアドレスを認めると、他人のアドレスを名乗って登録した
      # 利用者が、その利用者としてログインできる。
      assert_rejected encode(claims: { email_verified: false })
    end

    test "確認の記載が無い場合は受け付ける" do
      # email_verified は任意の要求である。付けない発行者もある。
      claims = verify(encode(claims: { email_verified: nil }))

      assert_equal "person@example.com", claims.email_address
    end

    test "知らない鍵の識別子は受け付けない" do
      assert_rejected encode(kid: "unknown-key")
    end

    test "組み立てられていない値は受け付けない" do
      assert_rejected "not-a-token"
      assert_rejected ""
      assert_rejected nil
    end

    test "拒否の理由は記録へ残る形で返す" do
      error = assert_raises(Oidc::IdToken::InvalidIdToken) { verify(encode(claims: { aud: "other" })) }

      # 文面へ id_token そのものを入れない。記録へ資格情報が写る。
      refute_includes error.message, encode
      assert error.message.present?
    end

    private
      def key
        @key ||= OpenSSL::PKey::RSA.generate(2048)
      end

      def jwks
        { "keys" => [ JWT::JWK.new(key, kid: KEY_ID).export ] }
      end

      # 公開鍵の材料を、共通鍵として使う形で取り出す。
      def jwk_public_key_material
        JWT::JWK.new(key, kid: KEY_ID).export[:n]
      end

      def payload(claims = {})
        {
          iss: ISSUER, aud: CLIENT_ID, sub: "subject-1",
          exp: 5.minutes.from_now.to_i, iat: Time.current.to_i,
          nonce: NONCE, email: "person@example.com", email_verified: true
        }.merge(claims).compact
      end

      def encode(key: nil, claims: {}, kid: KEY_ID)
        JWT.encode(payload(claims), key || self.key, "RS256", kid: kid)
      end

      def verify(token)
        Oidc::IdToken.verify(token, jwks: jwks, issuer: ISSUER, client_id: CLIENT_ID, nonce: NONCE)
      end

      def assert_rejected(token)
        assert_raises(Oidc::IdToken::InvalidIdToken, token.to_s[0, 20]) { verify(token) }
      end
  end
end
