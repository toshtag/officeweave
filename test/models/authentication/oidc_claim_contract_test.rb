require "test_helper"
require "jwt"

module Authentication
  # 認可サーバーから受け取る属性の対応。
  #
  # 文書（docs/development/authentication.md 5.6）に書いた対応を、そのまま
  # 固定する。文書と実装が離れると、認可サーバー側を設定する人が、
  # この製品が実際に何を読むのかを確かめられない。
  #
  # 読む属性を増やすと、認可サーバー側の設定とこの製品の振る舞いの
  # 結び付きが増える。増えていないことも、ここで確かめる。
  class OidcClaimContractTest < ActiveSupport::TestCase
    ISSUER = "https://idp.example.com".freeze
    CLIENT_ID = "officeweave".freeze
    NONCE = "a-request-nonce".freeze
    KEY_ID = "test-key".freeze

    # 文書に書いた 4 つ。ここを増やすときは文書も直す。
    READ_CLAIMS = %w[sub email email_verified nonce].freeze

    test "取り出す値は識別子とメールアドレスの 2 つだけとする" do
      assert_equal %i[subject email_address], Oidc::IdToken::Claims.members
    end

    test "識別子とメールアドレスを、名前のとおりに取り出す" do
      claims = verify(encode)

      assert_equal "subject-1", claims.subject
      assert_equal "person@example.com", claims.email_address
    end

    test "sub が無い id_token は拒む" do
      assert_rejected encode(claims: { sub: nil })
    end

    test "email が無い id_token は拒む" do
      assert_rejected encode(claims: { email: nil })
    end

    test "email が空文字の id_token は拒む" do
      assert_rejected encode(claims: { email: "" })
    end

    test "email_verified が無ければ、確かめられないものとして通す" do
      # 記載しない認可サーバーがある。記載が無いことを、確認済みでないことと
      # 同じ扱いにすると、その認可サーバーでは誰もログインできない。
      claims = verify(encode(claims: { email_verified: nil }))

      assert_equal "person@example.com", claims.email_address
    end

    test "email_verified が false の id_token は拒む" do
      assert_rejected encode(claims: { email_verified: false })
    end

    test "email_verified が文字列の true でも拒む" do
      # 真偽値の true だけを確認済みとして扱う。文字列を通すと、
      # 「"false"」も真として扱う実装へ滑りやすい。
      assert_rejected encode(claims: { email_verified: "true" })
    end

    test "nonce が要求と一致しない id_token は拒む" do
      assert_rejected encode(claims: { nonce: "別の要求のもの" })
    end

    test "文書に無い属性は読まない" do
      # 表示名や所属を送ってくる認可サーバーがある。受け取っても使わない。
      claims = verify(encode(claims: {
        name: "認可サーバー側の表示名", preferred_username: "person",
        groups: %w[administrators], picture: "https://idp.example.com/avatar.png"
      }))

      assert_equal "person@example.com", claims.email_address
      assert_equal %i[subject email_address], claims.to_h.keys
    end

    test "権限は認可サーバーの属性から決めない" do
      # groups を送られても、この製品側の役割は変わらない。
      user = users(:hanako)

      verify(encode(claims: { email: user.email_address, groups: %w[administrators] }))

      assert_not_predicate user.reload, :administrator?
    end

    test "利用者の引き当てはメールアドレスで行う" do
      # sub で引き当てる形にすると、認可サーバーを入れ替えたときに
      # 全利用者を結び付け直すことになる。
      user = users(:taro)
      claims = verify(encode(claims: { email: user.email_address, sub: "別の識別子" }))

      assert_equal user, User.find_by(email_address: claims.email_address)
    end

    test "読む属性の一覧が、文書に書いた 4 つと一致する" do
      documented = Rails.root.join("docs/development/authentication.md").read

      READ_CLAIMS.each { |claim| assert_includes documented, "`#{claim}`" }
    end

    private
      def key
        @key ||= OpenSSL::PKey::RSA.generate(2048)
      end

      def jwks
        { "keys" => [ JWT::JWK.new(key, kid: KEY_ID).export ] }
      end

      def payload(claims = {})
        {
          iss: ISSUER, aud: CLIENT_ID, sub: "subject-1",
          exp: 5.minutes.from_now.to_i, iat: Time.current.to_i,
          nonce: NONCE, email: "person@example.com", email_verified: true
        }.merge(claims).compact
      end

      def encode(claims: {})
        JWT.encode(payload(claims), key, "RS256", kid: KEY_ID)
      end

      def verify(token)
        Oidc::IdToken.verify(token, jwks: jwks, issuer: ISSUER, client_id: CLIENT_ID, nonce: NONCE)
      end

      def assert_rejected(token)
        assert_raises(Oidc::IdToken::InvalidIdToken) { verify(token) }
      end
  end
end
