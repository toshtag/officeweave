# データベースが拒んだ理由の読み取り。
#
# 例外の文面から制約の名前を探さない。文面はデータベースの版と表示言語で
# 変わる。変わった日に、拒まれたことは同じでも、画面へ理由を返せなくなる。
#
# 状態コードと制約の名前は、規格と定義で決まっている。そこだけを見る。
module DatabaseConstraint
  # 重なりを禁じる制約に触れた（SQL 標準 23P01）。
  EXCLUSION_VIOLATION = "23P01".freeze

  # 検査の制約に触れた（SQL 標準 23514）。引き金からの拒否もこの値で返す。
  CHECK_VIOLATION = "23514".freeze

  # 待ち合いになった場合に、もう一度だけ試す回数。
  #
  # 重なりを禁じる制約は、同時に届いた 2 つの書き込みで待ち合いになり得る。
  # 互いに相手の確定を待つためであり、データベースは片方を中断する。
  # 中断された側は、相手が確定した状態でもう一度試せば、待ちではなく
  # 制約に触れたという答えを受け取れる。それが利用者へ返すべき理由である。
  #
  # 2 回で足りる。1 回目で待ち合いになるのは相手がまだ確定していないから
  # であり、中断された時点で相手は確定している。
  ATTEMPTS = 2

  class << self
    def retrying_deadlock(attempts: ATTEMPTS)
      tries = 0

      begin
        tries += 1
        yield
      rescue ActiveRecord::Deadlocked
        raise if tries >= attempts

        retry
      end
    end

    def exclusion_violation?(error, constraint:)
      violated?(error, state: EXCLUSION_VIOLATION, constraint: constraint)
    end

    def check_violation?(error, constraint:)
      violated?(error, state: CHECK_VIOLATION, constraint: constraint)
    end

    private
      def violated?(error, state:, constraint:)
        result = pg_result(error)

        return false if result.nil?

        result.error_field(PG::PG_DIAG_SQLSTATE) == state &&
          result.error_field(PG::PG_DIAG_CONSTRAINT_NAME) == constraint
      end

      # 元の例外までたどる。ActiveRecord は自分の型で包み直すため、
      # 状態コードを持つのは包まれた側である。
      def pg_result(error)
        cause = error.cause

        cause.result if cause.respond_to?(:result)
      end
  end
end
