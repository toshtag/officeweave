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
      secret_key,
      mail_delivery,
      application_host,
      administrator_exists,
      webhook_allowlist,
      webhook_destinations
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

    def application_host
      host = ActionMailer::Base.default_url_options[:host]

      if host.present? && host != "example.com"
        ok("メール本文の URL", host)
      else
        warning("メール本文の URL", "APPLICATION_HOST を設定してください。通知から画面へ戻れません。")
      end
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
