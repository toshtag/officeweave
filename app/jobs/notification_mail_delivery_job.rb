require "net/smtp"
require "timeout"

# メールの送信をやり直す。
#
# 送信の失敗には、時間を置けば通る一時的なものと、
# 何度送っても通らない恒久的なものがある。
# 一時的な失敗をやり直さないと、送信サーバーの短い不調でメールが失われる。
# 恒久的な失敗をやり直すと、通らない送信を繰り返して他のジョブを詰まらせる。
#
# 実行は at-least-once とする。
# 送信サーバーが受理した直後に接続が切れた場合、同じメールが二度届くことがある。
# 送信の完了を確かめる手段がないため、届かないより届きすぎる側へ倒す。
class NotificationMailDeliveryJob < ActionMailer::MailDeliveryJob
  # ApplicationJob を継承しないため、同じ契約をここでも設定する。
  self.enqueue_after_transaction_commit = true

  # 初回に加えて 4 回やり直す。合計 5 回まで実行する。
  MAXIMUM_ATTEMPTS = 5

  # やり直しの待ち時間。短い不調を吸収しつつ、詰まりを長引かせない値にする。
  RETRY_INTERVALS = [ 5.seconds, 30.seconds, 2.minutes, 5.minutes ].freeze

  # 時間を置けば通る失敗。
  TRANSIENT_ERRORS = [
    SocketError,
    IOError,
    SystemCallError,
    Timeout::Error,
    Net::OpenTimeout,
    Net::ReadTimeout,
    Net::SMTPServerBusy,
    OpenSSL::SSL::SSLError
  ].freeze

  retry_on(*TRANSIENT_ERRORS, attempts: MAXIMUM_ATTEMPTS, wait: ->(executions) { interval_for(executions) })

  # 何度送っても通らない失敗。
  # retry_on へ登録しないことで、1 回で失敗として残る。
  # 握りつぶすと、届いていないことに誰も気付けない。
  # 一覧としても残す。どちらへ分類したかを読み取れるようにする。
  PERMANENT_ERRORS = [
    Net::SMTPAuthenticationError,
    Net::SMTPFatalError,
    Net::SMTPSyntaxError
  ].freeze

  def self.interval_for(executions)
    RETRY_INTERVALS.fetch(executions - 1, RETRY_INTERVALS.last)
  end
end
