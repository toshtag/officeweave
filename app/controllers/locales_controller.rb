# 表示言語の切り替えを受け付ける。
#
# 選択は session に保持する。
# 利用者ごとの設定として保存する方法は、利用者情報を扱う P4 で判断する。
class LocalesController < ApplicationController
  # ログイン画面でも言語を切り替えられるようにする。
  allow_unauthenticated_access

  def update
    session[:locale] = requested_locale if requested_locale

    redirect_to return_path
  end

  private
    def requested_locale
      available_locale(params[:locale])
    end

    # 外部サイトへの誘導に使われないよう、自サイト内の絶対パスだけを許可する。
    # 認証後の戻り先と同じ判定を使う。同じ「遷移先として認める経路」に、
    # 画面ごとに違う条件を置くと、緩いほうが抜け道になる。
    def return_path
      Authentication::LocalPath.permitted(params[:return_to]) || root_path
    end
end
