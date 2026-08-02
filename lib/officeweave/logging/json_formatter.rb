require "json"
require "logger"

module Officeweave
  module Logging
    # 記録を 1 行 1 件の JSON として出す。
    #
    # 記録を集める仕組みは 1 行を 1 件として読む。1 件が複数行にまたがると、
    # 例外のような長い記録だけが別々の件として集まる。改行は JSON の
    # 文字列として持たせ、行を分けない。
    #
    # 要求の識別子は接頭辞ではなく項目として出す。接頭辞にすると、
    # 集める側が文の先頭から切り出すことになる。
    class JsonFormatter < ::Logger::Formatter
      include ActiveSupport::TaggedLogging::Formatter

      # 小数点以下 3 桁までとする。1 件ずつの順序が読み取れれば足りる。
      TIME_PRECISION = 3

      def call(severity, time, _progname, message)
        line = { time: time.utc.iso8601(TIME_PRECISION), level: severity }

        "#{line.merge(fields_of(message)).to_json}\n"
      end

      private
        # 組み立てた項目は、そのまま項目として出す。文へ混ぜ直さない。
        def fields_of(message)
          fields = message.is_a?(Hash) ? message : { message: readable(message) }

          tags = current_tags
          return fields if tags.empty?

          # 最初のタグは要求の識別子である。config.log_tags の先頭を
          # request_id にしていることに依存する。
          fields = fields.merge(request_id: tags.first)
          fields = fields.merge(tags: tags.drop(1)) if tags.size > 1
          fields
        end

        def readable(message)
          case message
          when String then message
          when Exception then "#{message.message} (#{message.class})"
          else message.inspect
          end
        end
    end
  end
end
