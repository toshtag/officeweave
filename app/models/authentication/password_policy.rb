module Authentication
  # 新しく設定するパスワードへ求める最低限。
  #
  # 認証は単一要素だけで、多要素は持たない。総当たりと使い回しへ対抗できるのは
  # 長さだけであるため、最低長を 15 文字とし、文字種の混在は求めない。
  # 混在規則は覚えにくい短い値へ人を誘導し、長さの利点を打ち消す。
  #
  # 長さは文字数で数える。バイト数で数えると、同じ見た目でも日本語のほうが
  # 早く条件を満たしてしまう。`has_secure_password` が持つ 72 バイトの上限は
  # 別の制約であり、ここでは扱わない。
  #
  # 判定するのは、新しく割り当てられた平文だけとする。保存済みの digest からは
  # 長さも中身も復元できず、ここで扱える対象ではない。
  class PasswordPolicy
    MINIMUM_LENGTH = 15

    # 導入手順や設定の雛形へ現れてきた値。長さの条件とは別に、明示して拒む。
    # 長くしただけでは安全にならない値が、そのまま運用へ残ることを防ぐ。
    KNOWN_UNSAFE_VALUES = %w[
      change_me
      password
      officeweave
    ].freeze

    class << self
      # 満たしていない条件を返す。満たしている場合は nil を返す。
      #
      # 未入力は対象外とする。値を設定しない更新と、要件を満たさない値の設定は
      # 別のことであり、必須かどうかは呼ぶ側が決める。
      #
      # 既知の値は長さより先に判定する。同じ入力へ理由を 2 つ並べても、
      # 直し方は変わらない。
      def violation(value)
        return if value.nil? || value.empty?
        return :known_unsafe if known_unsafe?(value)
        return :too_short if value.length < MINIMUM_LENGTH

        nil
      end

      # 判定のときだけ前後の空白と大文字小文字の違いを無視する。
      # 元の値は加工しない。加工した値を保存すると、利用者が入力したものと
      # 実際に保存されたものが食い違う。
      #
      # 完全一致だけを見る。部分一致で拒むと、既知の値を含むだけの
      # 十分に長いパスワードまで使えなくなる。
      def known_unsafe?(value)
        return false unless value.is_a?(String)

        KNOWN_UNSAFE_VALUES.include?(value.strip.downcase)
      end
    end
  end
end
