# 決裁の要求が、どの時点の申請に対して作られたのかを見分けるための値。
#
# 更新の時刻では足りない。時刻の分解能より短いあいだに、差し戻し、修正、
# 再提出まで進むと、同じ段の位置と同じ時刻へ戻る。その場合、前の提出の
# ときに開いた画面からの決裁が通る。頻度の問題ではなく、競合を防ぐ契約が
# 時計の細かさに依存していることが問題である。
#
# 保存する値は、更新のたびに作り直す。順序は持たせない。順序を持たせると、
# 占有していない経路（申請の内容の編集）で同じ値を 2 つ作り得る。
class AddDecisionStateNonceToRequests < ActiveRecord::Migration[8.1]
  def up
    add_column :requests, :decision_state_nonce, :string

    # 既にある申請にも値を入れる。空のままだと、その申請だけ決裁できない。
    execute <<~SQL.squish
      UPDATE requests
      SET decision_state_nonce = md5(random()::text || clock_timestamp()::text || id::text)
      WHERE decision_state_nonce IS NULL
    SQL

    change_column_null :requests, :decision_state_nonce, false
  end

  def down
    remove_column :requests, :decision_state_nonce
  end
end
