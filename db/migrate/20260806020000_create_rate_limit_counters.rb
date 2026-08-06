class CreateRateLimitCounters < ActiveRecord::Migration[8.1]
  def change
    create_table :rate_limit_counters do |t|
      # 数える対象を表す値。制御部の名前と、数える単位（token や接続元）から作る。
      t.string :key, null: false
      t.integer :count, null: false, default: 0
      # この時刻を過ぎたら、次の数え上げが 1 から始め直す。
      t.datetime :expires_at, null: false

      t.timestamps
    end

    # 同じ key の行を 2 つ作らせない。数え上げは、この一意性の上で
    # ON CONFLICT を使って 1 文にまとめる。分かれると、web ごとに別の行を
    # 数えることになり、共有する意味が無くなる。
    add_index :rate_limit_counters, :key, unique: true
    # 後始末が、期限を過ぎた行だけを走査できるようにする。
    add_index :rate_limit_counters, :expires_at
  end
end
