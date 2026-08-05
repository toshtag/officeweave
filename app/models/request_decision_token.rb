# 決裁の要求が、どの申請の、どの段の、どの版に対して作られたのかを運ぶ値。
#
# 段の位置だけでは、要求が作られた時点の状態を識別できない。位置は同じ値へ
# 戻り得る。差し戻して再提出すれば 1 段目へ戻り、先の段の担当は、まだ来て
# いない段の位置を書いて送れる。どちらも、いま待っている位置と一致してしまう。
#
# 版を含めることで、申請が一度でも変わった時点の要求を区別できる。
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

      # 申請が変わるたびに変わる値。
      #
      # 状態の変更は必ず申請の行を書き換えるため、更新の時刻で足りる。
      # 秒より細かいところまで含める。同じ秒のうちに差し戻しと再提出が
      # 起きた場合に、区別が付かなくなる。
      def version_of(request)
        request.updated_at.utc.strftime("%Y%m%d%H%M%S%6N")
      end

      def verifier
        Rails.application.message_verifier(PURPOSE)
      end
  end
end
