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
    # 設定で指定された名前を解決できない。
    class UnknownProvider < StandardError; end

    # 実装の側が、設定へ書けない識別子を登録しようとした。
    class InvalidProviderName < StandardError; end

    PROVIDER_VARIABLE = "AUTHENTICATION_PROVIDER"

    @providers = {}

    class << self
      # 登録できるのは、設定へそのまま書ける識別子だけとする。
      #
      # 空文字や前後に空白を含む名前を受け入れると、それが登録済みになる。
      # 「空文字と前後に空白を含む値では起動しない」という設定の契約を、
      # 登録の側から迂回できてしまう。
      # 取り除いて登録し直すことはせず、登録そのものを失敗させる。
      def register(provider)
        name = provider.name_key.to_s
        raise InvalidProviderName, invalid_message(provider, name) unless usable_name?(name)

        @providers[name] = provider
      end

      def registered
        @providers.keys
      end

      # 名前から方式を解決する唯一の口とする。
      #
      # 設定の値は加工しない。前後の空白も大文字小文字も、誤記として扱う。
      # 似た名前を推測すると、意図しない方式で動く構成を作り得る。
      def fetch(name)
        @providers.fetch(name.to_s) { raise UnknownProvider, unknown_message(name) }
      end

      # 設定で指定された方式。設定そのものが無い場合だけ内部認証とする。
      #
      # 知らない名前は誤りとして扱い、内部認証へ落とさない。
      # 落とすと、外部認証を意図した構成が誤記だけで内部認証として起動し、
      # 使わなくなったパスワードが再び有効になる。
      def current
        fetch(ENV.fetch(PROVIDER_VARIABLE, InternalProvider.name_key))
      end

      private
        # strip は判定にだけ使う。取り除いた値を登録の対象にしない。
        def usable_name?(name)
          !name.empty? && name == name.strip
        end

        def invalid_message(provider, name)
          "#{provider} の name_key=#{name.inspect} は使用できません。" \
            "空文字、空白だけ、前後に空白を含む名前は登録できません。"
        end

        # 環境変数全体や資格情報は載せない。原因を読むのに要るのは、
        # 変数名、指定された値、選べる名前の 3 つだけである。
        def unknown_message(name)
          "#{PROVIDER_VARIABLE}=#{name.to_s.inspect} は登録されていません。" \
            "利用可能な認証方式: #{available_names}"
        end

        # 登録の順序は実行ごとに変わり得る。並べてから載せる。
        def available_names
          names = registered.sort
          names.empty? ? "なし" : names.join(", ")
        end
    end
  end
end
