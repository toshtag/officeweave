# 記録の形式と、要求・送信の要約。
#
# 記録の保管と回収は、組織の環境にある仕組みへ委ねている。
# LOG_FORMAT=json を指定した場合、その仕組みが読める形で出す。
#
# 値の検査はここで行う。知らない形式のまま起動させると、集める仕組みが
# JSON を待っているのに人向けの文が届き続ける。
format = Officeweave::Configuration::LogFormat.current

if format == Officeweave::Configuration::LogFormat::JSON
  # 書き出し先は変えない。形だけを変える。
  # 出力先の決め方は環境ごとの設定にあり、そこと二重に持たない。
  Rails.logger.formatter = Officeweave::Logging::JsonFormatter.new
end

# 購読は 1 度だけ登録する。to_prepare へ置くと、読み込みのたびに増える。
#
# 要求の経路は問い合わせ文字列を落として記録する。絞り込みの値が
# そのまま記録へ写り、集めた先へ残ることを避ける。
ActiveSupport::Notifications.subscribe("process_action.action_controller") do |event|
  payload = event.payload

  Officeweave::Logging.record(
    "http_request",
    method: payload[:method],
    path: payload[:path]&.split("?")&.first,
    status: payload[:status] || (payload[:exception] ? 500 : nil),
    controller: payload[:controller],
    action: payload[:action],
    duration_ms: event.duration.round(1),
    # 例外は種類だけを残す。文面には利用者が入力した値が入り得る。
    exception: payload[:exception]&.first,
    user_id: payload[:user_id],
    organization_id: payload[:organization_id]
  )
end

ActiveSupport::Notifications.subscribe("perform.active_job") do |event|
  job = event.payload[:job]

  Officeweave::Logging.record(
    "job_performed",
    job: job.class.name,
    job_id: job.job_id,
    queue: job.queue_name,
    # 何回目の実行かを残す。やり直しが続いているかを、記録だけで読み取れる。
    attempt: job.executions + 1,
    duration_ms: event.duration.round(1),
    exception: event.payload[:exception]&.first
  )
end
