class ApplicationJob < ActiveJob::Base
  # ジョブの投入を、トランザクションの確定後まで待つ。
  # 確定前に worker が取り出すと、まだ見えないレコードを読もうとして失敗する。
  self.enqueue_after_transaction_commit = true

  # 引数のレコードが消えている場合は、やり直しても結果が変わらない。
  discard_on ActiveJob::DeserializationError
end
