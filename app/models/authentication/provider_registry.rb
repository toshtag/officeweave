module Authentication
  # 認証方式の差し替え口。
  #
  # 既定は内部認証とする。外部の認証基盤を使う場合は、
  # 同じ 3 つの呼び出しに応える実装を登録して切り替える。
  #
  #   Authentication::ProviderRegistry.register(SomeProvider)
  #
  # 実装へ求めるのは次だけとする。
  #   name_key          設定で指定する名前
  #   authenticate      資格情報から利用者を返す。該当しなければ nil
  #   password_required? 画面でパスワードの入力を求めるか
  #
  # 呼び出しをこれ以上増やさない。増やすほど、外部の方式を足す手間が上がる。
  module ProviderRegistry
    class UnknownProvider < StandardError; end

    @providers = {}

    class << self
      def register(provider)
        @providers[provider.name_key.to_s] = provider
      end

      def registered
        @providers.keys
      end

      def fetch(name)
        @providers.fetch(name.to_s) { raise UnknownProvider, name.to_s }
      end

      # 設定で指定された方式。
      # 知らない名前が指定された場合は、内部認証へ落とす。
      # 認証できない状態で起動すると、誰も入れなくなる。
      def current
        fetch(ENV.fetch("AUTHENTICATION_PROVIDER", InternalProvider.name_key))
      rescue UnknownProvider
        Rails.logger.warn("知らない認証方式が指定されました。内部認証を使用します。")
        InternalProvider
      end
    end
  end
end
