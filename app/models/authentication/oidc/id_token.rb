require "jwt"

module Authentication
  module Oidc
    # OIDC の id_token の検証。
    #
    # ここを通った id_token は、そのままログインの根拠になる。
    # 検証の抜けは、誰でも任意の利用者としてログインできることに等しい。
    #
    # 署名の検証、期限の判定、鍵の選択は jwt へ委ねる。正確さと安全性が
    # 要求される領域を、依存を避けるためだけに自作しない（設計原則 4）。
    # 委ねる範囲は JWT.decode の 1 か所に閉じ、置き換えられる状態に保つ。
    #
    # 仕様が任意としている要求のうち、次はこの製品では必須とする。
    #
    #   nonce           要求と応答の対応を確かめる唯一の手がかりである
    #   email           利用者の突き合わせに使う
    #   email_verified  記載がある場合は true でなければ受け付けない
    module IdToken
      # 検証を通らなかった。理由は文面へ入れるが、id_token 自体は入れない。
      class InvalidIdToken < StandardError; end

      # 公開鍵の方式だけを認める。
      #
      # 一覧で渡す。渡さないと、id_token の側が方式を決められる。
      # 共通鍵の方式（HS256）を認めると、公開鍵を鍵として署名した
      # id_token が通る。
      ALGORITHMS = %w[RS256 RS384 RS512 ES256 ES384 ES512].freeze

      # 時計のずれを吸収する幅。発行者と自分の時計は一致しない。
      LEEWAY = 30.seconds

      Claims = Struct.new(:subject, :email_address, keyword_init: true)

      class << self
        def verify(token, jwks:, issuer:, client_id:, nonce:)
          raise InvalidIdToken, "id_token が空です" if token.blank?

          claims = decode(token, jwks: jwks, issuer: issuer, client_id: client_id)

          verify_issued_at(claims)
          verify_nonce(claims, nonce)
          verify_email(claims)

          Claims.new(subject: claims.fetch("sub"), email_address: claims.fetch("email"))
        end

        private
          def decode(token, jwks:, issuer:, client_id:)
            payload, = JWT.decode(
              token, nil, true,
              algorithms: ALGORITHMS,
              jwks: jwks,
              iss: issuer, verify_iss: true,
              aud: client_id, verify_aud: true,
              verify_expiration: true,
              verify_iat: true,
              # sub が無い id_token は、利用者を特定できない。
              required_claims: %w[iss aud exp iat sub],
              leeway: LEEWAY.to_i
            )

            payload
          rescue JWT::DecodeError, JWT::JWKError => error
            # 理由は種類だけを残す。文面へ id_token を入れない。
            raise InvalidIdToken, "id_token の検証に失敗しました (#{error.class.name.demodulize})"
          end

          # 未来に発行された id_token を受け付けない。
          #
          # jwt の verify_iat は、iat が数値であることまでを見る。
          # 発行時刻が未来であることは、こちらで見る。
          def verify_issued_at(claims)
            return if claims.fetch("iat") <= (Time.current + LEEWAY).to_i

            raise InvalidIdToken, "発行時刻が未来です"
          end

          # 要求と応答の対応を確かめる。別の要求への応答を持ち込ませない。
          def verify_nonce(claims, nonce)
            given = claims["nonce"]

            return if given.present? && ActiveSupport::SecurityUtils.secure_compare(given.to_s, nonce.to_s)

            raise InvalidIdToken, "nonce が要求と一致しません"
          end

          def verify_email(claims)
            raise InvalidIdToken, "email がありません" if claims["email"].blank?

            # 記載がない場合は確かめられない。記載があり false のものは受け付けない。
            return unless claims.key?("email_verified")
            return if claims["email_verified"] == true

            raise InvalidIdToken, "email が確認されていません"
          end
      end
    end
  end
end
