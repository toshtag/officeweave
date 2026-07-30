# ジョブの投入。
#
# 投入そのものが失敗した場合に、黙って成功として扱わない。
# 記録も残らず送信もされない状態は、あとから気付く手がかりがない。
#
# 投入は、業務のトランザクションが確定した後に行われる（ApplicationJob を参照）。
# そのため投入が失敗した時点で、利用者の操作は既に保存されている。
# ここでは失敗を記録したうえで送出し直す。
#
# 操作の保存と投入を 1 つの単位にするには outbox が必要になる。
# 本書の範囲では扱わない。キューは業務データと同じ PostgreSQL にあるため、
# 投入が失敗する状況では、要求そのものも成立していないことが多い。
module JobEnqueue
  def self.perform(description)
    yield
  rescue StandardError => error
    Rails.error.report(error, handled: false, context: { enqueue: description })
    raise
  end
end
