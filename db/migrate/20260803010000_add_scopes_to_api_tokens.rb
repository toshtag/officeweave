# API トークンへ、許可する範囲を足す。
#
# 既に発行した token は範囲を持たない状態にする。既定値として全範囲を
# 入れる形も採らない。入れると、範囲の一覧を後から増やしたときに、
# 既存の token が新しい範囲を持たないことになる。「指定が無い」ことを
# 「すべて」として扱い、後から増える範囲にも追随させる。
class AddScopesToApiTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :api_tokens, :scopes, :string, array: true
  end
end
