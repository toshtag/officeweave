class RequireScopesOnApiTokens < ActiveRecord::Migration[8.1]
  # 範囲を持たない token は、これまで「すべて」として扱っていた。
  # その「すべて」は判定の時点で決まるため、資源を足すと、過去に発行した
  # token へ自動で開いていた。
  #
  # 発行の時点で決まっていた範囲を、値としてそのまま置く。今読める範囲は
  # 1 つも狭まらず、これから足す資源だけが開かなくなる。
  #
  # 一覧は模型の定数を参照しない。移行は、後で定数が変わっても同じ結果に
  # なる必要がある。ここへ書き写した値が、この移行を適用した時点の「すべて」である。
  SCOPES_AT_MIGRATION = %w[announcements events departments users].freeze

  def up
    execute <<~SQL.squish
      UPDATE api_tokens
         SET scopes = ARRAY[#{SCOPES_AT_MIGRATION.map { |scope| "'#{scope}'" }.join(', ')}]::character varying[]
       WHERE scopes IS NULL
    SQL

    change_column_null :api_tokens, :scopes, false
  end

  def down
    change_column_null :api_tokens, :scopes, true
  end
end
