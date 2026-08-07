# 表示言語の切り替えを受け付ける。
#
# 選択は session に保持する。ログインしていない相手にも切り替えさせるため、
# 利用者の行へは書かない。ログイン後に持ち越したい場合は、自分の設定
# （`User#locale`）が受け持つ。
class LocalesController < ApplicationController
  records_no_audit :update,
                   reason: "表示言語の切り替えであり、権限にも組織の資料にも影響しない"

  # ログイン画面でも言語を切り替えられるようにする。
  allow_unauthenticated_access reason: "ログインの画面でも表示する言語を選べるようにする。変えるのはその端末の表示だけで、他の利用者にも記録にも影響しない"

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
