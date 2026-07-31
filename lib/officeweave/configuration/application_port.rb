module Officeweave
  module Configuration
    # APPLICATION_PORT の値の正本。
    #
    # 利用者がメール本文の URL から接続する公開ポートである。
    # ホストから web コンテナへ公開する WEB_PORT とは別物とする。
    # 逆プロキシの背後では、利用者が接続するポートと内部のポートが一致しない。
    # WEB_PORT を公開 URL へ流用すると、内部のポートがメールへ混ざる。
    #
    # 利用者が 80 または 443 以外のポートへ接続する場合に指定する。
    # 逆プロキシの有無とは独立している。逆プロキシ自体が非標準のポートで
    # 公開されている構成でも必要になる。
    module ApplicationPort
      VARIABLE = "APPLICATION_PORT".freeze

      # 設定として受け付けられない値だった。
      class InvalidApplicationPort < ArgumentError; end

      # 先頭の 0 を認めない。補正すると、設定に書いた値と実際に動く値が食い違う。
      FORMAT = /\A[1-9]\d*\z/

      RANGE = (1..65_535).freeze

      class << self
        # 未設定と空文字はどちらも「明示しない」として扱う。
        # URL へポートを付けないことは誤設定ではない。
        def resolve(raw)
          return nil unless raw.is_a?(String)
          return nil if raw.empty?

          raise InvalidApplicationPort, message(raw) unless FORMAT.match?(raw)

          port = Integer(raw, 10)
          raise InvalidApplicationPort, message(raw) unless RANGE.cover?(port)

          port
        end

        private
          def message(raw)
            <<~TEXT.strip
              #{VARIABLE}=#{raw.inspect} は受け入れられません。
              #{RANGE.first} から #{RANGE.last} までの整数を指定してください。
              指定しない場合は、公開 URL へポートを付けません。
            TEXT
          end
      end
    end
  end
end
