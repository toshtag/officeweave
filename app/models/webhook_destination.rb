require "ipaddr"
require "socket"

# Webhook の送信先。
#
# 宛先は管理者が登録する。管理者を信頼するだけでは足りない。
# 誤って内部の宛先を登録した場合も、権限を奪われた場合も、
# このアプリケーションが内部ネットワークへの入口になってしまう。
#
# そのため、URL の形と名前解決の結果の両方を検査し、
# 実際に接続する IP アドレスまで決めて返す。
#
#   destination = WebhookDestination.resolve!("https://hooks.example.com/events")
#   destination.uri          # 検証済みの URI
#   destination.ip_address   # 接続に使う検証済みの IP
#
# 名前解決は差し替えられる。テストを外部の DNS へ依存させないためである。
class WebhookDestination
  # 受け付けられない理由。
  #
  # 画面と送信の記録の双方で使うため、文言ではなく安定した符号で表す。
  # 内部の IP アドレスや名前解決の結果は、符号にも文言にも含めない。
  class Error < StandardError
    REASONS = %i[
      invalid_url
      unsupported_scheme
      missing_host
      credentials_not_allowed
      fragment_not_allowed
      port_not_allowed
      resolution_failed
      resolution_timeout
      destination_not_allowed
      invalid_allowlist
    ].freeze

    attr_reader :reason

    def initialize(reason)
      raise ArgumentError, "知らない理由: #{reason}" unless REASONS.include?(reason)

      @reason = reason
      super(reason.to_s)
    end
  end

  ALLOWED_SCHEMES = %w[http https].freeze

  # 80 と 443 以外を許さない。
  # 任意のポートを許すと、内部ネットワークの走査に使える。
  ALLOWED_PORTS = [ 80, 443 ].freeze

  # 保存の操作が名前解決で止まり続けないようにする。
  # 時間切れは許可ではなく拒否として扱う。
  DNS_RESOLUTION_TIMEOUT = 2

  # 外部への送信先として不適切な範囲。
  #
  # 私用・ループバック・リンクローカルに加え、
  # 文書例示や予約済みの範囲も塞ぐ。外部の宛先として妥当な用途がない。
  BLOCKED_RANGES = %w[
    0.0.0.0/8
    10.0.0.0/8
    100.64.0.0/10
    127.0.0.0/8
    169.254.0.0/16
    172.16.0.0/12
    192.0.0.0/24
    192.0.2.0/24
    192.168.0.0/16
    198.18.0.0/15
    198.51.100.0/24
    203.0.113.0/24
    224.0.0.0/4
    240.0.0.0/4
    ::/128
    ::1/128
    fc00::/7
    fe80::/10
    ff00::/8
    2001:db8::/32
  ].map { |range| IPAddr.new(range) }.freeze

  # 閉じたネットワーク内の宛先を明示的に許すための設定。
  # 既定は空とし、設定した組織だけが内部宛先を使えるようにする。
  ALLOWLIST_VARIABLE = "WEBHOOK_PRIVATE_DESTINATION_ALLOWLIST"

  # 名前解決の既定の実装。
  #
  # OS の設定と /etc/hosts に従う。追加の gem は使わない。
  # getaddrinfo は C の中で止まるため、別のスレッドへ逃がして待ち時間を区切る。
  DEFAULT_RESOLVER = lambda do |hostname, port|
    addresses = nil
    failure = nil

    worker = Thread.new do
      addresses = Addrinfo.getaddrinfo(hostname, port, Socket::AF_UNSPEC, Socket::SOCK_STREAM)
    rescue StandardError => exception
      failure = exception
    end

    raise Error.new(:resolution_timeout) unless worker.join(DNS_RESOLUTION_TIMEOUT)
    raise Error.new(:resolution_failed) if failure

    addresses.map(&:ip_address)
  end

  attr_reader :uri, :ip_address

  class << self
    # 宛先を検証し、接続に使う IP を決める。
    # 受け付けられない場合は Error を送出する。
    def resolve!(url, resolver: nil, allowlist: nil)
      new(url,
          resolver: resolver || configured_resolver,
          allowlist: allowlist || allowlist_from_environment).resolve!
    end

    # 名前解決の実装。
    #
    # テスト環境だけは、実行環境の DNS へ依存しない実装へ差し替える。
    # 設定は読むだけとし、テストの途中で書き換えない。
    def configured_resolver
      Rails.application.config.x.webhook_destination_resolver || DEFAULT_RESOLVER
    end

    # 設定された許可リスト。構文が不正な場合は黙って無視しない。
    def allowlist_from_environment(value = ENV[ALLOWLIST_VARIABLE])
      value.to_s.split(",").map(&:strip).reject(&:empty?).map { |entry| allowlist_origin(entry) }.to_set
    end

    # 比較のため小文字にし、末尾のドットを落とす。
    # 同じ宛先が別の表記で許可リストから外れないようにする。
    def normalize_hostname(hostname)
      return nil if hostname.blank?

      hostname.downcase.sub(/\.\z/, "")
    end

    def origin(scheme, hostname, port)
      "#{scheme}://#{hostname}:#{port}"
    end

    private
      # 許可リストの 1 件を origin へ正規化する。
      # ワイルドカードと CIDR は扱わない。曖昧な指定は、意図より広く許してしまう。
      def allowlist_origin(entry)
        raise Error.new(:invalid_allowlist) if entry.include?("*")

        uri = URI.parse(entry)

        raise Error.new(:invalid_allowlist) unless ALLOWED_SCHEMES.include?(uri.scheme)
        raise Error.new(:invalid_allowlist) if uri.host.blank?
        raise Error.new(:invalid_allowlist) unless ALLOWED_PORTS.include?(uri.port)
        # 経路や条件を含む指定は許さない。origin 単位でだけ判断する。
        raise Error.new(:invalid_allowlist) unless uri.path.blank? || uri.path == "/"
        raise Error.new(:invalid_allowlist) if uri.query.present? || uri.fragment.present?
        raise Error.new(:invalid_allowlist) if uri.userinfo.present?

        hostname = normalize_hostname(uri.hostname)
        raise Error.new(:invalid_allowlist) if hostname.blank?

        origin(uri.scheme, hostname, uri.port)
      rescue URI::InvalidURIError
        raise Error.new(:invalid_allowlist)
      end
  end

  def initialize(url, resolver:, allowlist:)
    @url = url
    @resolver = resolver
    @allowlist = allowlist
  end

  def resolve!
    @uri = parse_uri
    @hostname = normalized_hostname

    addresses = resolve_addresses
    raise Error.new(:resolution_failed) if addresses.empty?

    @ip_address = choose_address(addresses)

    self
  end

  private
    attr_reader :url, :resolver, :allowlist, :hostname

    def parse_uri
      uri = URI.parse(url.to_s)

      raise Error.new(:invalid_url) if uri.scheme.blank?
      raise Error.new(:unsupported_scheme) unless ALLOWED_SCHEMES.include?(uri.scheme.downcase)
      raise Error.new(:missing_host) if uri.host.blank?
      raise Error.new(:credentials_not_allowed) if uri.userinfo.present?
      raise Error.new(:fragment_not_allowed) if uri.fragment.present?
      raise Error.new(:port_not_allowed) unless ALLOWED_PORTS.include?(uri.port)

      uri
    rescue URI::InvalidURIError
      raise Error.new(:invalid_url)
    end

    def normalized_hostname
      normalized = self.class.normalize_hostname(uri.hostname)

      raise Error.new(:missing_host) if normalized.blank?
      # zone identifier を含む宛先は、どの経路へ出るかが構成に依存する。外部の宛先として扱わない。
      raise Error.new(:invalid_url) if normalized.include?("%")

      normalized
    end

    def resolve_addresses
      Array(resolver.call(hostname, uri.port)).map(&:to_s).uniq
    rescue Error
      raise
    rescue StandardError
      raise Error.new(:resolution_failed)
    end

    # 解決した IP のうち 1 つでも外部送信に適さないものがあれば、宛先ごと拒否する。
    # 一部だけ許すと、解決の順番によって通る場合と通らない場合が生まれる。
    #
    # 許可リストにある origin では、この判定だけを外す。
    # URL の検査、名前解決、接続先の固定、証明書の検証はそのまま行う。
    def choose_address(addresses)
      unless allowed_origin?
        addresses.each do |address|
          raise Error.new(:destination_not_allowed) unless permitted_address?(address)
        end
      end

      addresses.first
    end

    def allowed_origin?
      allowlist.include?(self.class.origin(uri.scheme.downcase, hostname, uri.port))
    end

    def permitted_address?(address)
      ip = IPAddr.new(address)
      # IPv4-mapped の表記で判定を抜けられないようにする。
      ip = ip.native if ip.ipv6?

      BLOCKED_RANGES.none? { |range| range.include?(ip) }
    rescue IPAddr::Error
      false
    end
end
