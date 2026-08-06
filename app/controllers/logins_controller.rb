# ログイン中の端末の一覧と終了。
#
# ログインそのもの（/session）とは別の経路とする。ここで扱うのは、
# 既に始まっているログインを見て、必要なものを終わらせることである。
#
# 資格情報の置き場所とは関わらない。外部の認証方式へ切り替えた環境でも、
# ログインの記録はこの製品が持つ。
class LoginsController < ApplicationController
  records_audit :destroy, :destroy_all

  def index
    # 期限を過ぎた記録は並べない。認証には使えず、並べると終わらせる操作が
    # 必要に見える。消すのは定期実行が行う。
    @logins = Current.user.sessions.usable.order(last_active_at: :desc)
  end

  def destroy
    # 自分のログインだけを対象にする。識別子を受け取って引き当てると、
    # 他の利用者のログインを終わらせられる。
    login = Current.user.sessions.find_by(id: params[:id])

    return head :not_found if login.nil?

    login.destroy
    record_revocation(1)

    redirect_to logins_path, notice: t("logins.revoked", count: 1)
  end

  # 今の端末以外をまとめて終わらせる。
  #
  # 操作した端末を対象へ含めない。自分を締め出す操作を、一覧の主要な操作と
  # して置かない。ログアウトは /session が扱う。
  def destroy_all
    others = Current.user.sessions.where.not(id: Current.session.id)
    count = others.count

    others.destroy_all
    record_revocation(count)

    redirect_to logins_path, notice: t("logins.revoked", count: count)
  end

  private
    # 終わらせるものが無かった場合は記録しない。
    # 操作の記録として残す価値が無く、記録だけが増える。
    def record_revocation(count)
      return if count.zero?

      record_audit_event("sessions_revoked", target: Current.user, details: { count: count })
    end
end
