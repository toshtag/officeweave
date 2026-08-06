# 外部の宛先へ送る本文の形。
#
# 受け取る側は、この形に合わせて処理を書く。形を変えると、相手の処理が
# 黙って壊れる。壊れたことは相手の側でしか分からない。
#
# 形に版を入れる。受け取る側が、対応している版かどうかを本文だけで判断できる。
# 版を入れないと、鍵の有無を数えて推測することになる。
#
# 版を上げるのは、鍵を消す・名前を変える・意味を変えるときだけとする。
# 鍵を足すのは上げない。読み飛ばせば、これまでの処理はそのまま動く。
module WebhookPayload
  # 本文の形の版。
  VERSION = 1

  # どの製品のどの形かを示す。相手が複数の送り元を受ける場合に区別できる。
  SCHEMA = "officeweave.webhook".freeze

  # すべての出来事が必ず持つ鍵。
  COMMON_KEYS = %i[schema version event occurrence occurred_at].freeze

  # 出来事ごとに足す鍵。
  #
  # 対象の内容そのものは送らない。本文や添付は宛先の先で保管され、
  # 送り元からは消せない。受け取る側は識別子で読み直す。
  EVENT_KEYS = {
    "announcement_published" => %i[subject_type subject_id title],
    "event_invited" => %i[subject_type subject_id title],
    "request_submitted" => %i[subject_type subject_id title],
    "request_approved" => %i[subject_type subject_id title],
    "request_returned" => %i[subject_type subject_id title]
  }.freeze

  class << self
    def build(event:, occurrence:, occurred_at:, attributes:)
      {
        schema: SCHEMA,
        version: VERSION,
        event: event,
        occurrence: occurrence,
        occurred_at: occurred_at.iso8601
      }.merge(attributes.slice(*EVENT_KEYS.fetch(event)))
    end

    def keys_for(event)
      COMMON_KEYS + EVENT_KEYS.fetch(event)
    end
  end
end
