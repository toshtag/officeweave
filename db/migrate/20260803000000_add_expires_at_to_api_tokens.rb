# API トークンへ有効期限を足す。
#
# 既に発行した token は期限を持たない状態にする。既定値を入れて期限を
# 与えると、この版へ入れ替えた時点で外部との接続が切れる日が決まる。
# 切れた理由が、入れ替えと結び付かない。
class AddExpiresAtToApiTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :api_tokens, :expires_at, :datetime
  end
end
