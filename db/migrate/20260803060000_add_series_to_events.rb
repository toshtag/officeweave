# 繰り返し予定の回を、同じ繰り返しとして辿れるようにする。
#
# 各回は独立した予定として作る。規則だけを持って読むときに展開する形は
# 採らない。参照範囲、予約との結び付き、参加者の指名は、いずれも予定 1 件を
# 対象にしており、展開する形にすると、それらすべてが規則を知る必要がある。
#
# 最初の回も自分の識別子を持つ。持たせないと、繰り返しの一部かどうかの
# 判定が「最初の回だけ別」という形になる。
class AddSeriesToEvents < ActiveRecord::Migration[8.1]
  def change
    add_reference :events, :series, foreign_key: { to_table: :events }

    # 同じ繰り返しの回をまとめて読む。
    add_index :events, [ :series_id, :starts_at ]
  end
end
