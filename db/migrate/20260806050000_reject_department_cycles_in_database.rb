class RejectDepartmentCyclesInDatabase < ActiveRecord::Migration[8.1]
  # 部門の階層の循環を、データベース側でも拒む。
  #
  # 循環は 1 行だけでは判定できない。上へたどって自分に戻るかを見る必要が
  # あり、検査の制約では書けない。引き金で書き込みの直前に確かめる。
  #
  # たどる途中の行を共有で占有する。占有しないと、互いに相手を親にする 2 つの
  # 書き込みが、どちらも相手の変更前の姿を見て通り、循環が成立する。占有すると
  # 一方が待ち、待ち合いになった場合はデータベースが片方を中断する。
  # 循環が残るより、片方が失敗するほうがよい。
  #
  # 上限を置く。既に循環している記録に当たっても終わるようにする。
  MAXIMUM_DEPTH = 100

  def up
    detach_existing_cycles

    execute <<~SQL
      CREATE FUNCTION departments_reject_cycle() RETURNS trigger
      LANGUAGE plpgsql AS $$
      DECLARE
        ancestor_id bigint;
        steps integer := 0;
      BEGIN
        IF NEW.parent_id IS NULL THEN
          RETURN NEW;
        END IF;

        IF NEW.parent_id = NEW.id THEN
          RAISE EXCEPTION 'department cannot be its own parent'
            USING ERRCODE = '23514', CONSTRAINT = 'departments_must_not_form_a_cycle';
        END IF;

        ancestor_id := NEW.parent_id;

        WHILE ancestor_id IS NOT NULL LOOP
          IF ancestor_id = NEW.id THEN
            RAISE EXCEPTION 'department hierarchy would form a cycle'
              USING ERRCODE = '23514', CONSTRAINT = 'departments_must_not_form_a_cycle';
          END IF;

          steps := steps + 1;

          IF steps > #{MAXIMUM_DEPTH} THEN
            RAISE EXCEPTION 'department hierarchy is too deep to verify'
              USING ERRCODE = '23514', CONSTRAINT = 'departments_must_not_form_a_cycle';
          END IF;

          SELECT parent_id INTO ancestor_id
            FROM departments
           WHERE id = ancestor_id
             FOR SHARE;
        END LOOP;

        RETURN NEW;
      END;
      $$;
    SQL

    execute <<~SQL
      CREATE TRIGGER departments_reject_cycle
        BEFORE INSERT OR UPDATE OF parent_id ON departments
        FOR EACH ROW EXECUTE FUNCTION departments_reject_cycle();
    SQL
  end

  def down
    execute "DROP TRIGGER departments_reject_cycle ON departments"
    execute "DROP FUNCTION departments_reject_cycle()"
  end

  private
    # 既にある循環を断つ。
    #
    # 引き金はこれからの書き込みだけを見る。足しただけでは、既に循環して
    # いる記録はそのまま残り、不変条件は成り立たない。
    #
    # 断つ位置は、上へたどっても根へ着かない部門のうち、最も新しいものと
    # する。その 1 本を外せば、その循環は解ける。外した部門は根になり、
    # 配下はそのまま付いてくる。名前も所属も変わらない。
    #
    # 循環は複数あり得るため、無くなるまで繰り返す。上限を置き、
    # 想定外の形で終わらない状態を作らない。
    def detach_existing_cycles
      MAXIMUM_DEPTH.times do
        detached = execute(<<~SQL).values.flatten
          WITH RECURSIVE reachable AS (
            SELECT id FROM departments WHERE parent_id IS NULL
            UNION
            SELECT d.id FROM departments d JOIN reachable r ON d.parent_id = r.id
          )
          UPDATE departments
             SET parent_id = NULL, updated_at = NOW()
           WHERE id = (
             SELECT MAX(id) FROM departments WHERE id NOT IN (SELECT id FROM reachable)
           )
          RETURNING id
        SQL

        return if detached.empty?

        say "循環していた階層を断ちました（部門 #{detached.first}）"
      end

      raise "部門の循環を断ち切れませんでした。手元で階層を確かめてください"
    end
end
