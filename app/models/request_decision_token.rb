# 決裁の要求が、どの申請の、どの段の、どの版に対して作られたのかを運ぶ値。
#
# 段の位置だけでは、要求が作られた時点の状態を識別できない。位置は同じ値へ
# 戻り得る。差し戻して再提出すれば 1 段目へ戻り、先の段の担当は、まだ来て
# いない段の位置を書いて送れる。どちらも、いま待っている位置と一致してしまう。
#
# 申請が持つ決裁の状態の値を含めることで、一度でも変わった時点の要求を区別
# できる。更新の時刻は使わない。時刻の細かさより短いあいだに差し戻し、修正、
# 再提出まで進むと、同じ段と同じ時刻へ戻る。競合を防ぐ契約が、時計の分解能に
# 依存してよい理由はない。
# 署名するのは、利用者が未来の状態に対する値を自分で作れないようにするため
# である。決裁できる相手を、その段の担当へ限る判断は別にある。ここで守るのは
# 「その利用者が実際に見た状態に対する操作か」だけとする。
class RequestDecisionToken
  # 決裁の画面を開いたまま置かれる時間の見込み。
  #
  # 版が変われば、この時間内でも合わなくなる。ここで切るのは、状態が
  # まったく変わらないまま置かれ続けた要求だけである。
  EXPIRES_IN = 1.day

  # 用途を分ける。分けないと、別の目的で署名した値をここへ持ち込める。
  PURPOSE = "request_decision"

  class << self
    # いま見えている状態に対する値を作る。
    # 待っている段が無い申請では作らない。
    def issue(request:, actor:)
      position = request.current_step&.position
      return if position.nil?

      verifier.generate(claim(request, actor, position), expires_in: EXPIRES_IN, purpose: PURPOSE)
    end

    # 占有して読み直した申請と突き合わせる。
    #
    # 署名が違う、期限が切れた、別の申請や別の利用者のもの、版が違うものは
    # すべて一致しないものとして扱う。理由は区別しない。区別すると、
    # 送った側が何を変えれば通るのかを探れる。
    def matches?(token, request:, actor:)
      claimed = verifier.verified(token.to_s, purpose: PURPOSE)
      return false if claimed.nil?

      position = request.current_step&.position
      return false if position.nil?

      claimed == claim(request, actor, position)
    end

    private
      def claim(request, actor, position)
        {
          "request_id" => request.id,
          "actor_id" => actor.id,
          "step_position" => position,
          "version" => version_of(request)
        }
      end

      # 申請が変わるたびに作り直される値。申請自身が持つ。
      def version_of(request)
        request.decision_state_nonce
      end

      def verifier
        Rails.application.message_verifier(PURPOSE)
      end
  end
end
