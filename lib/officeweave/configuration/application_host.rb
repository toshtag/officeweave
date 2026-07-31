module Officeweave
  module Configuration
    # APPLICATION_HOST の値の正本。
    #
    # この値は 2 か所で使う。運用環境で受け入れる Host と、メール本文の URL である。
    # 受け入れる側だけを固めても、作る側で不正な値を保存できると、
    # 内部の稼働確認だけが通り、利用者からは到達できない構成を作れる。
    # 稼働確認も同じ値を Host ヘッダーへ付けるためである。
    #
    # 値は加工しない。前後の空白を取り除いたり、スキームやポートを外したりして
    # 受理すると、設定に書いた値と実際に動く値が食い違う。誤設定は推測して直さず、
    # 起動を失敗させる。
    module ApplicationHost
      VARIABLE = "APPLICATION_HOST".freeze

      # 設定として受け付けられない値だった。
      class InvalidApplicationHost < ArgumentError; end

      # DNS のラベル。63 文字以内で、先頭と末尾をハイフンにしない。
      LABEL = /[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?/i

      # 末尾の点は付けない。Host ヘッダー側は点を落として届くため、
      # 設定に残すと一致しなくなる。
      DNS_NAME = /\A#{LABEL}(?:\.#{LABEL})*\z/

      # IPv6 は Host ヘッダーとして有効な角括弧付きの形式だけを認める。
      IPV6 = /\A\[[0-9a-f.:]*:[0-9a-f.:]*\]\z/i

      MAX_LENGTH = 253

      class << self
        # 環境変数そのものが無い場合だけ default を使う。
        # 明示された空文字は誤設定として扱い、既定値へ落とさない。
        def resolve(raw, default:)
          return default if raw.nil?
          raise InvalidApplicationHost, message(raw) unless valid?(raw)

          raw
        end

        private
          def valid?(value)
            return false unless value.is_a?(String)
            return false if value.empty? || value.length > MAX_LENGTH

            value.match?(DNS_NAME) || value.match?(IPV6)
          end

          # 環境変数の内容そのものは載せない。設定値だけを inspect で示す。
          def message(raw)
            <<~TEXT.strip
              #{VARIABLE}=#{raw.inspect} は受け入れられません。
              利用者が接続するホスト名だけを指定してください。
              スキーム、経路、ポート、前後の空白は含めません。
              例: officeweave.example.com、localhost、192.0.2.10、[2001:db8::10]
            TEXT
          end
      end
    end
  end
end
