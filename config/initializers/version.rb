# 版数は VERSION ファイルを唯一の出所とする。
# 複数の場所へ書くと、更新し忘れた側が実態と食い違う。
module OfficeWeave
  VERSION = Rails.root.join("VERSION").read.strip.freeze
end
