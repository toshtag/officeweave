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

    # 形式は正しいが、別の実装が既に使用している識別子だった。
    class DuplicateProviderName < StandardError; end

    PROVIDER_VARIABLE = "AUTHENTICATION_PROVIDER"

    @providers = {}

    class << self
      # 登録できるのは、設定へそのまま書ける識別子だけとする。
      #
      # 空文字や前後に空白を含む名前を受け入れると、それが登録済みになる。
      # 「空文字と前後に空白を含む値では起動しない」という設定の契約を、
      # 登録の側から迂回できてしまう。
      # 取り除いて登録し直すことはせず、登録そのものを失敗させる。
      #
      # 識別子は方式ごとに 1 つとする。後から登録した方式で黙って置き換えると、
      # 設定に書いた名前と実際に動く実装が食い違う。とりわけ internal を
      # 奪われると、設定が無い場合の既定まで別の実装に変わる。
      def register(provider)
        name = provider.name_key.to_s
        raise InvalidProviderName, invalid_message(provider, name) unless usable_name?(name)

        existing = @providers[name]
        if existing && !same_implementation?(existing, provider)
          raise DuplicateProviderName, duplicate_message(name, existing, provider)
        end

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

        # 再読み込みでは、同じ定数が別のクラスへ入れ替わる。
        # これを衝突として拒むと、開発中は画面を開くたびに起動できなくなる。
        # 完全修飾名が同じものは、同じ実装の読み直しとして扱う。
        def same_implementation?(existing, provider)
          return true if existing.equal?(provider)

          name = qualified_name(provider)
          !name.nil? && name == qualified_name(existing)
        end

        # 名前を持たない実装は、読み直しかどうかを判別できない。別物として扱う。
        def qualified_name(provider)
          name = provider.name if provider.respond_to?(:name)
          name.to_s.empty? ? nil : name
        end

        def duplicate_message(name, existing, provider)
          "認証方式の識別子 #{name.inspect} は #{existing} が使用しています。" \
            "#{provider} は同じ識別子を登録できません。"
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
