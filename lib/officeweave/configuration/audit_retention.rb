module Officeweave
  module Configuration
    # AUDIT_RETENTION_DAYS の値の正本。
    #
    # 監査記録を残す日数である。指定した場合だけ、その日数より古い記録を
    # 定期実行が消す。指定しなければ記録は消えない。
    #
    # 既定値を持たない。既定で消す形にすると、この版へ入れ替えただけで
    # 過去の記録が消える組織が出る。監査記録は、消えたこと自体が
    # 後から確かめられない。
    #
    # 誤った値は起動の時点で失敗させる。読み取れない値を「指定なし」として
    # 扱うと、保持しているつもりの組織で記録が消え続け、あるいは消している
    # つもりの組織で溜まり続ける。どちらも気付くのは後になる。
    module AuditRetention
      VARIABLE = "AUDIT_RETENTION_DAYS".freeze

      # 設定として受け付けられない値だった。
      class InvalidAuditRetention < ArgumentError; end

      # 先頭の 0 を認めない。補正すると、設定に書いた値と実際に動く値が食い違う。
      FORMAT = /\A[1-9]\d*\z/

      # 1 日より短い保持は受け付けない。日の単位で判断する設定である。
      MINIMUM_DAYS = 1

      class << self
        # 実行環境から読む唯一の場所とする。
        # 読む側が増えるほど、変数名と既定の扱いが写される。
        def days = resolve(ENV[VARIABLE])

        # 未設定と空文字はどちらも「消さない」として扱う。
        def resolve(raw)
          return nil unless raw.is_a?(String)
          return nil if raw.empty?

          raise InvalidAuditRetention, message(raw) unless FORMAT.match?(raw)

          Integer(raw, 10)
        end

        private
          def message(raw)
            <<~TEXT.strip
              #{VARIABLE}=#{raw.inspect} は受け入れられません。
              #{MINIMUM_DAYS} 以上の整数を指定してください。
              指定しない場合は、監査記録を消しません。
            TEXT
          end
      end
    end
  end
end
