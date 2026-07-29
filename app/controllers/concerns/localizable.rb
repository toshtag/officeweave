# 表示言語を決めて、要求の処理中だけ適用する。
#
# 決め方の優先順位は次のとおり。
#   1. 利用者に設定された言語
#   2. 画面で選んだ言語（保持している場合）
#   3. ブラウザーが送る言語の希望
#   4. 既定の言語
#
# 対応していない言語が指定された場合は、次の候補へ落とす。
module Localizable
  extend ActiveSupport::Concern

  included do
    around_action :switch_locale
  end

  private
    def switch_locale(&action)
      I18n.with_locale(current_locale, &action)
    end

    def current_locale
      user_locale || stored_locale || preferred_locale || I18n.default_locale
    end

    def user_locale
      available_locale(Current.user&.locale)
    end

    def stored_locale
      available_locale(session[:locale])
    end

    # ブラウザーが送る Accept-Language から、対応している言語を選ぶ。
    # 品質値による重み付けまでは扱わない。並び順の先頭から順に評価する。
    def preferred_locale
      request.get_header("HTTP_ACCEPT_LANGUAGE").to_s
        .split(",")
        .filter_map { |tag| available_locale(tag.split(";").first&.strip&.split("-")&.first) }
        .first
    end

    def available_locale(value)
      return nil if value.blank?

      locale = value.to_s.downcase.to_sym
      locale if I18n.available_locales.include?(locale)
    end
end
