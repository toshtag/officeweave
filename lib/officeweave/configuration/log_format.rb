module Officeweave
  module Configuration
    # LOG_FORMAT の値の正本。
    #
    # 記録の保管と回収は、組織の環境にある仕組みへ委ねている。
    # 委ねる先が構造化された記録を読む場合に json を指定する。
    #
    # 既定は行形式とする。既定を json にすると、この版へ入れ替えただけで
    # 記録の形が変わり、既に組んである回収の仕組みが読めなくなる。
    #
    # 知らない値では起動しない。行形式へ落とすと、集める仕組みが JSON を
    # 待っているのに人向けの文が届き続ける。届いていないことに気付くのは、
    # 記録を探したときになる。
    module LogFormat
      VARIABLE = "LOG_FORMAT".freeze

      # 設定として受け付けられない値だった。
      class InvalidLogFormat < ArgumentError; end

      TEXT = "text".freeze
      JSON = "json".freeze

      FORMATS = [ TEXT, JSON ].freeze

      class << self
        # 実行環境から読む唯一の場所とする。
        def current = resolve(ENV[VARIABLE])

        def structured? = current == JSON

        # 未設定と空文字はどちらも行形式として扱う。
        # 補正はここだけとし、値の前後の空白も誤設定として扱う。
        def resolve(raw)
          return TEXT unless raw.is_a?(String)
          return TEXT if raw.empty?

          raise InvalidLogFormat, message(raw) unless FORMATS.include?(raw)

          raw
        end

        private
          def message(raw)
            <<~TEXT_MESSAGE.strip
              #{VARIABLE}=#{raw.inspect} は受け入れられません。
              #{FORMATS.join(" または ")} を指定してください。
              指定しない場合は #{TEXT} を使います。
            TEXT_MESSAGE
          end
      end
    end
  end
end
