module Authentication
  # OIDC 連携。
  #
  # 設定の解決は Officeweave::Configuration::Oidc、認可サーバーとの通信は
  # Oidc::Client、id_token の検証は Oidc::IdToken が受け持つ。
  # ここでは、それらを組み立てる場所を 1 つにまとめる。
  module Oidc
    class << self
      # 認可サーバーとの通信を作る差し替え口。
      #
      # テストから差し替える。実際の TLS と実際の HTTP で確かめるために、
      # 名前解決と証明書の検証元を渡した通信が必要になる。
      # 運用では未設定であり、通常の通信を作る。
      attr_accessor :client_factory

      def settings = Officeweave::Configuration::Oidc.current

      def configured? = !settings.nil?

      def client(current = settings)
        client_factory ? client_factory.call(current) : Client.new(current)
      end
    end
  end
end
