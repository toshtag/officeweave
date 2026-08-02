module Officeweave
  # 集める仕組みへ向けた記録。
  #
  # 人が読む記録は Rails が既に出している。ここで出すのは、要求 1 件、
  # 送信 1 件を 1 行で表した要約であり、機械が読むためのものである。
  #
  # 行形式では出さない。人が読む形式のままで要約を二重に出すと、
  # 同じことが 2 行で並ぶ。
  module Logging
    class << self
      def record(event, **fields)
        return unless Officeweave::Configuration::LogFormat.structured?

        # 値が無い項目は落とす。空の項目は、集める側で「値が無い」と
        # 「項目が無い」の区別を要求する。
        Rails.logger.info({ event: event }.merge(fields.compact))
      end
    end
  end
end
