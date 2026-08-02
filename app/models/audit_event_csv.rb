# 監査記録の書き出し。
#
# 生成は CsvTransfer を通す。数式として解釈され得るセルの保護を、
# 他の書き出しと同じ形で行うためである。
#
# 取り込みは持たない。監査記録は、この製品の中で起きた操作の記録であり、
# 外から与えられるものではない。取り込みの経路を作ると、記録を後から
# 作れる状態になる。
class AuditEventCsv
  HEADERS = %w[
    organization_code
    recorded_at
    action
    actor_name
    actor_email_address
    target_type
    target_id
    ip_address
    details
  ].freeze

  # まとめて読み込む件数。蓄積した記録を一度に読み込まない。
  BATCH_SIZE = 1_000

  def initialize(scope, batch_size: BATCH_SIZE)
    @scope = scope
    @batch_size = batch_size
  end

  # 画面から呼ぶ。全体を組み立てて返す。
  def export
    CsvTransfer.generate(headers: HEADERS) do |csv|
      each_row { |row| csv << row }
    end
  end

  # コマンドから呼ぶ。1 行ずつ書き出し、全体をメモリへ載せない。
  def write(io)
    CsvTransfer.write(io, headers: HEADERS) do |csv|
      each_row { |row| csv << row }
    end
  end

  private
    # 識別子の順に読む。監査記録は書き足すだけであり、識別子の順が
    # 記録された順になる。画面の並び（新しい順）は、まとめ読みでは使えない。
    def each_row
      @scope.reorder(:id).includes(:organization, :actor).find_each(batch_size: @batch_size) do |event|
        yield row_for(event)
      end
    end

    def row_for(event)
      [
        event.organization.code,
        # 時刻は UTC の固定した書式で出す。読み手の言語や地域で変わらない。
        event.created_at.utc.iso8601,
        # 操作の名前は翻訳しない。表示言語で列の値が変わると、同じ組織の
        # 書き出しが時期によって別物になる。
        event.action,
        event.actor&.name,
        event.actor&.email_address,
        event.target_type,
        event.target_id,
        event.ip_address,
        event.details.to_json
      ]
    end
end
