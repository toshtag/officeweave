class CreateReservations < ActiveRecord::Migration[8.1]
  def change
    # 期間の重なりを除外する制約を張るために必要。
    # 単一列の等価比較と範囲の重なりを、ひとつの索引で扱えるようになる。
    enable_extension "btree_gist"

    create_table :reservations do |t|
      t.references :organization, null: false, foreign_key: true
      t.references :resource, null: false, foreign_key: true
      t.references :reserver, null: false, foreign_key: { to_table: :users }
      # 予定と結びつける場合に使う。結びつけない予約もある。
      t.references :event, foreign_key: true
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.string :purpose

      t.timestamps
    end

    add_index :reservations, %i[resource_id starts_at]

    # 同じ設備・備品の時間帯が重ならないことを、データベース側で保証する。
    # 模型側の確認だけでは、同時に申し込まれた場合に両方が通ってしまう。
    # 終端を含まない範囲とし、直前の終了時刻と次の開始時刻が同じ場合は重ならない扱いにする。
    # 日時の列は時間帯を持たない型で、値は常に協定世界時で保存される。
    # 時間帯付きの範囲へ変換すると、変換関数が実行環境の設定に依存するため索引に使えない。
    reversible do |direction|
      direction.up do
        execute <<~SQL
          ALTER TABLE reservations
          ADD CONSTRAINT reservations_must_not_overlap
          EXCLUDE USING gist (
            resource_id WITH =,
            tsrange(starts_at, ends_at, '[)') WITH &&
          )
        SQL
      end

      direction.down do
        execute "ALTER TABLE reservations DROP CONSTRAINT reservations_must_not_overlap"
      end
    end
  end
end
