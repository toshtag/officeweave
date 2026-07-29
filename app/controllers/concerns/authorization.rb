# 操作できる範囲の判定。
#
# 権限は「管理者」と「一般利用者」の 2 段階だけとする。
# 役割を細かく分けるのは、実際に区別が必要な操作が現れてからにする。
module Authorization
  extend ActiveSupport::Concern

  included do
    helper_method :administrator?
  end

  private
    def administrator?
      Current.user&.administrator? || false
    end

    # 管理者だけが実行できる操作へ付ける。
    # 権限が足りない場合は、資源の存在を隠さずに拒否する。
    # ログイン済みの利用者にとって、部門や利用者の存在自体は既知である。
    def require_administrator
      return if administrator?

      render "shared/forbidden", status: :forbidden, formats: :html
    end
end
