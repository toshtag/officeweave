# 実ブラウザーを要する層を除いたテストの一覧と、その分け方。
#
# 自動実行では、この一覧を複数の仕事へ分けて同時に走らせる。分け方を
# workflow へ書き写すと、層を足したときに片方だけが古くなる。
#
# Rails の読み込みには乗せない。テストを走らせるための道具であり、製品の
# 実行時には要らない。lib/tasks は自動読み込みの対象から外れているため、
# ここへ置いて rake の task から直接読み込む。
module Officeweave
  module TestFiles
    ROOT = File.expand_path("../..", __dir__)

    # 実ブラウザーは追加の service を要する。dummy と fixtures は試験ではない。
    EXCLUDED = "test/{dummy,fixtures,browser}/**/*_test.rb".freeze

    EVERY = "test/**/*_test.rb".freeze

    class << self
      def all
        (glob(EVERY) - glob(EXCLUDED)).sort
      end

      # total 個へ分けたうちの index 番目を返す。番号は 1 から数える。
      #
      # 名前順に 1 件ずつ配る。まとめて切ると同じ層が 1 つの組へ寄り、
      # 組ごとの所要時間が偏る。
      def shard(index, total)
        unless total >= 1 && index >= 1 && index <= total
          raise ArgumentError, "分け方が違う: #{index}/#{total}"
        end

        all.each_with_index.filter_map { |path, position| path if position % total == index - 1 }
      end

      # "1/3" の形で受け取る。
      def parse(specification)
        index, total = specification.to_s.split("/", 2).map { |value| Integer(value, exception: false) }
        raise ArgumentError, "分け方が違う: #{specification}" if index.nil? || total.nil?

        shard(index, total)
      end

      private
        def glob(pattern)
          Dir.glob(File.join(ROOT, pattern)).map { |path| path.delete_prefix("#{ROOT}/") }
        end
    end
  end
end
