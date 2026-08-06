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

  class << self
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
