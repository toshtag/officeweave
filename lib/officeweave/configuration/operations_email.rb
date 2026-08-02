module Officeweave
  module Configuration
    # OPERATIONS_EMAIL の値の正本。
    #
    # 稼働の異常を知らせる宛先である。業務の管理者ではなく、環境を預かる
    # 運用者を指す。データベースへ到達できない状態を、業務の担当者へ
    # 知らせても手が無い。
    #
    # 既定値を持たない。指定しなければ知らせない。既定で管理者へ送る形に
    # すると、この版へ入れ替えただけで、業務の担当者へ運用の通知が届く。
    #
    # 宛先は 1 つだけとする。複数へ配りたい場合は、受け取る側の仕組み
    # （転送や配布用のアドレス）で分ける。ここで区切り文字を決めると、
    # 送信の設定と宛先の書式を、この製品が二重に持つことになる。
    module OperationsEmail
      VARIABLE = "OPERATIONS_EMAIL".freeze

      # 設定として受け付けられない値だった。
      class InvalidOperationsEmail < ArgumentError; end

      # 受け付ける形は 1 つの宛先だけとする。空白と区切り文字を認めない。
      FORMAT = /\A[^@\s,]+@[^@\s,]+\.[^@\s,]+\z/

      class << self
        # 実行環境から読む唯一の場所とする。
        def current = resolve(ENV[VARIABLE])

        def resolve(raw)
          return nil unless raw.is_a?(String)
          return nil if raw.empty?

          raise InvalidOperationsEmail, message(raw) unless FORMAT.match?(raw)

          raw
        end

        private
          def message(raw)
            <<~TEXT.strip
              #{VARIABLE}=#{raw.inspect} は受け入れられません。
              1 つのメールアドレスを指定してください。
              指定しない場合は、稼働の異常を知らせません。
            TEXT
          end
      end
    end
  end
end
