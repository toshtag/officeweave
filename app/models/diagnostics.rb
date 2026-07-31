require "ipaddr"

# 運用時の構成を確認する。
#
# 「起動している」ことと「正しく動く」ことは別である。
# 送信設定の不備や、実行し忘れた移行は、使われて初めて分かる。
class Diagnostics
  def run
    [
      database_connection,
      pending_migrations,
      required_extensions,
      storage_writable,
      attachment_routes,
      secret_key,
      mail_delivery,
      application_host,
      administrator_exists,
      authentication_provider,
      webhook_allowlist,
      webhook_destinations,
      *queue_checks
    ]
  end

  private
    def ok(name, detail = nil) = { name: name, status: :ok, detail: detail }
    def warning(name, detail) = { name: name, status: :warning, detail: detail }
    def error(name, detail) = { name: name, status: :error, detail: detail }

    def database_connection
      version = ActiveRecord::Base.connection.select_value("SELECT version()")
      ok("データベースへの接続", version.to_s.split(",").first)
    rescue StandardError => exception
      error("データベースへの接続", exception.message)
    end

    def pending_migrations
      pending = ActiveRecord::Base.connection_pool.migration_context.needs_migration?

      if pending
        error("データベースの移行", "未適用の移行があります。bin/rails db:migrate を実行してください。")
      else
        ok("データベースの移行", "すべて適用済み")
      end
    rescue StandardError => exception
      error("データベースの移行", exception.message)
    end

    def required_extensions
      required = %w[btree_gist pg_trgm]
      installed = ActiveRecord::Base.connection.extensions
      missing = required - installed

      if missing.empty?
        ok("データベースの拡張機能", required.join(", "))
      else
        error("データベースの拡張機能", "不足: #{missing.join(', ')}")
      end
    rescue StandardError => exception
      error("データベースの拡張機能", exception.message)
    end

    def storage_writable
      path = ActiveStorage::Blob.service.try(:root)
      return warning("ファイルの保存先", "ローカルディスク以外の保存先です") if path.blank?

      FileUtils.mkdir_p(path)
      probe = File.join(path, ".officeweave-diagnose")
      File.write(probe, "")
      File.delete(probe)

      ok("ファイルの保存先", path.to_s)
    rescue StandardError => exception
      error("ファイルの保存先", exception.message)
    end

    # 添付ファイルの取得経路。
    #
    # 保存基盤が作る経路は、署名付きの ID を知っている相手へ
    # ログインの有無も文書の参照範囲も問わず配信する。
    # 設定を戻しても画面は動くため、稼働中の構成として確かめる。
    def attachment_routes
      standard = Rails.application.routes.routes.count do |route|
        route.defaults[:controller].to_s.start_with?("active_storage/")
      end

      if standard.zero?
        ok("添付ファイルの取得経路", "文書の配下の経路だけ")
      else
        error("添付ファイルの取得経路",
              "保存基盤の経路が #{standard} 件あります。" \
              "config.active_storage.draw_routes = false を設定してください。")
      end
    rescue StandardError => exception
      error("添付ファイルの取得経路", exception.message)
    end

    def secret_key
      if Rails.application.secret_key_base.present?
        ok("署名に使う鍵", "設定されています")
      else
        error("署名に使う鍵", "SECRET_KEY_BASE を設定してください。")
      end
    rescue StandardError => exception
      error("署名に使う鍵", exception.message)
    end

    def mail_delivery
      method = ActionMailer::Base.delivery_method

      case method
      when :smtp
        address = ActionMailer::Base.smtp_settings[:address]
        ok("メールの送信", "送信先: #{address}")
      when :file
        warning("メールの送信", "ファイルへ書き出す設定です。運用環境では SMTP_ADDRESS を設定してください。")
      else
        warning("メールの送信", "送信しない設定です。通知はアプリ内にだけ残ります。")
      end
    end

    # 確かめるのは、設定を書いたかどうかではなく、
    # メールを受け取った利用者の端末からその URL へ戻れる見込みがあるかである。
    #
    # 設定元では判定できない。配布用の構成は APPLICATION_HOST が未設定でも
    # localhost をコンテナへ渡すため、環境変数の有無では
    # 「設定しなかった」と「localhost を明示した」を区別できない。
    def application_host
      options = ActionMailer::Base.default_url_options
      host = options[:host].to_s

      if host.blank?
        warning("メール本文の URL", "APPLICATION_HOST を設定してください。通知から画面へ戻れません。")
      elsif Rails.env.production? && local_only_host?(host)
        warning("メール本文の URL",
                "#{public_url_authority(options)} は利用者の端末を指します。" \
                "利用者が接続できる APPLICATION_HOST を設定してください。")
      else
        ok("メール本文の URL", public_url_authority(options))
      end
    end

    # 受け取った端末自身へ戻ってしまう公開先か。
    #
    # 設定としては正しいため起動は拒否しない。単一端末での試用や、
    # 逆プロキシを整える前の確認では、この値のまま動かせる必要がある。
    # 組織内の DNS 名は端末から到達できる場合があるため、名前だけでは注意にしない。
    def local_only_host?(host)
      normalized = host.downcase
      return true if normalized == "localhost" || normalized.end_with?(".localhost")

      IPAddr.new(normalized.delete_prefix("[").delete_suffix("]")).loopback?
    rescue IPAddr::Error
      # 起動時に検査済みだが、診断だけを取り出して使う場合にも失敗させない。
      false
    end

    # 公開ポートを指定している場合は、ホスト名と合わせて示す。
    def public_url_authority(options)
      options[:port] ? "#{options[:host]}:#{options[:port]}" : options[:host].to_s
    end

    def administrator_exists
      count = User.active.where(role: "administrator").count

      if count.positive?
        ok("管理者", "#{count} 人")
      else
        error("管理者", "有効な管理者がいません。bin/rails db:seed で初期利用者を作成してください。")
      end
    rescue StandardError => exception
      error("管理者", exception.message)
    end

    # ジョブに関わる検査。
    #
    # 永続キューを使わない設定では、表も worker も存在しない。
    # 当てはまらない検査を失敗として並べると、本当の不備が埋もれる。
    def queue_checks
      adapter = ActiveJob::Base.queue_adapter_name.to_s

      unless adapter == "solid_queue"
        return [ warning("ジョブの実行方式",
                         "永続キューを使わない設定です（#{adapter}）。ジョブは保存されません。") ]
      end

      [ queue_database, queue_settings, job_workers, failed_jobs ]
    end

    # ジョブ用の表があるか。
    #
    # 存在しない表へ問い合わせると、その接続のトランザクションが壊れる。
    # 以降の検査まで巻き込むため、カタログの照会で確かめる。
    def queue_tables_present?
      SolidQueue::Job.connection.table_exists?("solid_queue_jobs")
    rescue StandardError
      false
    end

    # ジョブの保存先。
    #
    # primary とは別の論理データベースへ置く。
    # 接続できない、または表が無い状態では、送信が一切行われない。
    def queue_database
      if queue_tables_present?
        ok("ジョブの保存先", SolidQueue::Job.connection_db_config.database)
      else
        error("ジョブの保存先",
              "ジョブ用の表がありません。bin/rails db:prepare を実行してください。")
      end
    rescue StandardError => exception
      error("ジョブの保存先", exception.message)
    end

    # 実行 thread 数と接続数の整合。
    #
    # worker は実行 thread のほかに待機と heartbeat でも接続を使う。
    # thread 数を接続数まで使い切ると、待機の側が接続を取れずに止まる。
    def queue_settings
      threads = ENV.fetch("JOB_THREADS", 2).to_i
      processes = ENV.fetch("JOB_PROCESSES", 1).to_i
      connections = ENV.fetch("QUEUE_DATABASE_CONNECTIONS", 5).to_i

      if threads < 1 || processes < 1 || connections < 1
        return error("ジョブの実行設定",
                     "JOB_THREADS、JOB_PROCESSES、QUEUE_DATABASE_CONNECTIONS は 1 以上にしてください。")
      end

      if threads > connections - 2
        error("ジョブの実行設定",
              "JOB_THREADS=#{threads} に対して QUEUE_DATABASE_CONNECTIONS=#{connections} が不足しています。" \
              "待機と heartbeat の分を含め、実行 thread 数 + 2 以上にしてください。")
      else
        ok("ジョブの実行設定", "process #{processes}、thread #{threads}、接続 #{connections}")
      end
    end

    # worker の稼働。
    #
    # web だけが動いていても、ジョブは溜まるだけで実行されない。
    # 配布用の構成では worker の不在を失敗として扱う。
    def job_workers
      return error("ジョブの実行", "ジョブ用の表がありません。") unless queue_tables_present?

      # 種別の名前には実行方式が付く（Supervisor(fork) など）。前方一致で数える。
      supervisors = SolidQueue::Process.where("kind LIKE 'Supervisor%'").count
      workers = SolidQueue::Process.where(kind: "Worker").count

      if workers.positive?
        ok("ジョブの実行", "supervisor #{supervisors}、worker #{workers}")
      elsif Rails.env.production?
        error("ジョブの実行",
              "worker が動いていません。docker compose -f compose.production.yaml up -d worker を実行してください。")
      else
        warning("ジョブの実行", "worker が動いていません。ジョブは溜まるだけで実行されません。")
      end
    rescue StandardError => exception
      error("ジョブの実行", exception.message)
    end

    # 失敗したジョブ。
    #
    # 自動では消さない。存在するだけで起動を止めることもしない。
    # 気付ける形にして、運用者の判断へ委ねる。
    def failed_jobs
      return error("失敗したジョブ", "ジョブ用の表がありません。") unless queue_tables_present?

      count = SolidQueue::FailedExecution.count

      if count.zero?
        ok("失敗したジョブ", "なし")
      else
        warning("失敗したジョブ", "#{count} 件あります。bin/jobs_status --failed で内容を確認してください。")
      end
    rescue StandardError => exception
      error("失敗したジョブ", exception.message)
    end

    # 稼働中の認証方式。
    #
    # 知らない名前は起動時に拒否するため、通常はここへ現れない。
    # 表示するのはクラス名ではなく、設定で指定する名前とする。
    # 設定した値と見比べられないと、確認にならない。
    def authentication_provider
      ok("認証方式", Authentication::ProviderRegistry.current.name_key)
    rescue StandardError => exception
      error("認証方式", exception.message)
    end

    # 内部宛先の許可設定。
    #
    # 構文が不正なまま起動すると、Webhook の送信がすべて拒否される。
    # 黙って無視せず、ここで気付けるようにする。
    def webhook_allowlist
      allowlist = WebhookDestination.allowlist_from_environment

      if allowlist.empty?
        ok("Webhook の内部宛先の許可", "設定なし（外部の宛先だけを許可）")
      else
        warning("Webhook の内部宛先の許可",
                "#{allowlist.size} 件の origin を許可しています。内部ネットワークへの送信を許す設定です。")
      end
    rescue WebhookDestination::Error
      error("Webhook の内部宛先の許可",
            "#{WebhookDestination::ALLOWLIST_VARIABLE} の書式が不正です。" \
            "http または https の origin をカンマ区切りで指定してください。")
    end

    # 登録済みの Webhook 宛先。
    #
    # 既存のデータは自動で変更しない。送信時に拒否されるため、
    # 使えなくなっている宛先を管理者が把握できるようにする。
    # 出力には宛先の ID と名称だけを載せ、URL や解決した IP は載せない。
    def webhook_destinations
      endpoints = WebhookEndpoint.active.ordered
      return ok("Webhook の送信先", "有効な送信先がありません") if endpoints.empty?

      rejected = endpoints.filter_map do |endpoint|
        WebhookDestination.resolve!(endpoint.url)
        nil
      rescue WebhookDestination::Error => exception
        "##{endpoint.id} #{endpoint.name}（#{exception.reason}）"
      end

      if rejected.empty?
        ok("Webhook の送信先", "#{endpoints.size} 件すべて送信できます")
      else
        error("Webhook の送信先", "送信できない宛先: #{rejected.join(' / ')}")
      end
    rescue StandardError => exception
      error("Webhook の送信先", exception.message)
    end
end
