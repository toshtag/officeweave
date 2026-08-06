module Officeweave
  module Configuration
    # WEBHOOK_DELIVERY_RETENTION_DAYS の値の正本。
    #
    # 外部への送信の記録を残す日数である。指定した場合だけ、その日数より古い
    # 記録を定期実行が消す。指定しなければ消えない。
    #
    # 既定値を持たない。既定で消す形にすると、この版へ入れ替えただけで
    # 過去の送信の記録が消える組織が出る。
    #
    # 誤った値は起動の時点で失敗させる。読み取れない値を「指定なし」として
    # 扱うと、消しているつもりの組織で溜まり続ける。
    module WebhookDeliveryRetention
      VARIABLE = "WEBHOOK_DELIVERY_RETENTION_DAYS".freeze

      class InvalidWebhookDeliveryRetention < ArgumentError; end

      # 先頭の 0 を認めない。補正すると、設定に書いた値と実際に動く値が食い違う。
      FORMAT = /\A[1-9]\d*\z/

      MINIMUM_DAYS = 1

      class << self
        def days = resolve(ENV[VARIABLE])

        def resolve(raw)
          return nil unless raw.is_a?(String)
          return nil if raw.empty?

          raise InvalidWebhookDeliveryRetention, message(raw) unless FORMAT.match?(raw)

          Integer(raw, 10)
        end

        private
          def message(raw)
            <<~TEXT.strip
              #{VARIABLE}=#{raw.inspect} は受け入れられません。
              #{MINIMUM_DAYS} 以上の整数を指定してください。
              指定しない場合は、送信の記録を消しません。
            TEXT
          end
      end
    end
  end
end
