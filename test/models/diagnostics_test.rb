require "test_helper"
require "timeout"
require "tmpdir"

class DiagnosticsTest < ActiveSupport::TestCase
  # 待機はすべて上限を持たせる。退行を CI の停止ではなく失敗として受け取るため。
  STORAGE_PROBE_WORKERS = 16
  PREPARATION_TIMEOUT = 10
  COMPLETION_TIMEOUT = 10
  OUTCOME_TIMEOUT = 5
  CLEANUP_TIMEOUT = 5

  setup { @checks = Diagnostics.new.run }

  test "確認の一覧を返す" do
    assert_operator @checks.size, :>=, 8
    assert(@checks.all? { |check| check[:name].present? })
    assert(@checks.all? { |check| %i[ok warning error].include?(check[:status]) })
  end

  test "データベースへの接続を確認する" do
    check = find("データベースへの接続")

    assert_equal :ok, check[:status]
    assert_match "PostgreSQL", check[:detail]
  end

  test "必要な拡張機能を確認する" do
    check = find("データベースの拡張機能")

    assert_equal :ok, check[:status]
    assert_match "btree_gist", check[:detail]
    assert_match "pg_trgm", check[:detail]
  end

  test "移行が適用済みであることを確認する" do
    assert_equal :ok, find("データベースの移行")[:status]
  end

  test "ファイルの保存先へ書き込めることを確認する" do
    assert_equal :ok, find("ファイルの保存先")[:status]
  end

  # 保存先の確認は、実行ごとに違う名前のファイルを作る。
  # 固定名だと、同時に走った診断どうしが同じファイルを消し合う。
  #
  # 待ち時間ではなく Queue で足並みをそろえる。待ち時間で揃えると、
  # 遅い環境で先後がずれ、退行を見逃す。
  test "ファイルの保存先の確認を同時に実行できる" do
    with_isolated_storage_root do |root|
      ready = Queue.new
      start = Queue.new
      outcomes = Queue.new
      threads = []
      remaining = []

      begin
        STORAGE_PROBE_WORKERS.times do
          threads << Thread.new do
            ready << :ready
            start.pop

            outcomes << Diagnostics.new.send(:storage_writable)
          rescue StandardError => error
            outcomes << error
          end
        end

        Timeout.timeout(PREPARATION_TIMEOUT) { STORAGE_PROBE_WORKERS.times { ready.pop } }
        STORAGE_PROBE_WORKERS.times { start << true }
        threads.each { |thread| assert thread.join(COMPLETION_TIMEOUT), "確認が終わりませんでした" }

        results = Timeout.timeout(OUTCOME_TIMEOUT) { STORAGE_PROBE_WORKERS.times.map { outcomes.pop } }
        failures = results.grep(Exception)

        assert_empty failures, failures.map { |error| "#{error.class}: #{error.message}" }.join("\n")
        assert(results.all? { |result| result[:status] == :ok },
               results.reject { |result| result[:status] == :ok }.inspect)
      ensure
        # 回収は保存先を戻す前に終える。途中で失敗した場合でも、生き残った
        # thread が共有の保存先へ書きに行くことがない。
        remaining = release_and_join_storage_threads(threads, start)
      end

      # 元の失敗があればそちらが先に伝わる。ここまで来た場合だけ確かめる。
      assert_empty remaining, "停止できない診断の thread が残りました"
      assert_empty Dir.children(root)
    end
  end

  # 正常に終わった確認は、保存先へ何も残さない。
  test "ファイルの保存先の確認はプローブを残さない" do
    with_isolated_storage_root do |root|
      result = Diagnostics.new.send(:storage_writable)

      assert_equal :ok, result[:status]
      assert_empty Dir.children(root)
      assert_not File.exist?(root.join(".officeweave-diagnose"))
    end
  end

  test "添付ファイルの取得経路が文書の配下だけであることを確認する" do
    check = find("添付ファイルの取得経路")

    assert_equal :ok, check[:status]
  end

  test "有効な管理者がいない場合は失敗として扱う" do
    User.update_all(role: "member")

    assert_equal :error, Diagnostics.new.run.find { |c| c[:name] == "管理者" }[:status]
  end

  test "無効にされた管理者は数えない" do
    # 通常の経路では最後の管理者を無効にできない。
    # ここで確かめるのは、それでも管理者不在になった場合に気づけることである。
    User.where(role: "administrator").update_all(deactivated_at: Time.current)

    assert_equal :error, Diagnostics.new.run.find { |c| c[:name] == "管理者" }[:status]
  end

  test "稼働中の認証方式を表示する" do
    check = find("認証方式")

    assert_equal :ok, check[:status]
    assert_equal "internal", check[:detail]
  end

  test "解決できない認証方式は失敗として扱う" do
    # 通常は起動時に拒否されるため、稼働中には現れない。
    # 診断だけを取り出して使う場合にも、原因が読めるようにする。
    original = ENV["AUTHENTICATION_PROVIDER"]
    ENV["AUTHENTICATION_PROVIDER"] = "does-not-exist"

    check = Diagnostics.new.run.find { |c| c[:name] == "認証方式" }

    assert_equal :error, check[:status]
    assert_includes check[:detail], "AUTHENTICATION_PROVIDER"
    assert_includes check[:detail], "does-not-exist"
  ensure
    if original.nil?
      ENV.delete("AUTHENTICATION_PROVIDER")
    else
      ENV["AUTHENTICATION_PROVIDER"] = original
    end
  end

  test "送信しない設定は注意として扱う" do
    check = find("メールの送信")

    assert_includes %i[warning ok], check[:status]
  end

  # 配布用の構成は、APPLICATION_HOST が未設定でも localhost を環境変数として渡す。
  # 環境変数の有無では設定漏れを判別できないため、実際の公開先で判定する。
  test "運用環境で利用者の端末を指す公開 URL は注意として扱う" do
    [ "localhost", "portal.localhost", "127.0.0.1", "127.20.30.40", "[::1]",
      "[::ffff:127.0.0.1]", "[::ffff:7f00:1]" ].each do |host|
      check = application_host_check(host: host, application_host: "localhost")

      assert_equal :warning, check[:status], host
      assert_includes check[:detail], host
      assert_includes check[:detail], "APPLICATION_HOST"
    end
  end

  test "運用環境で接続先を特定しない公開 URL は注意として扱う" do
    [ "0.0.0.0", "[::]", "[::ffff:0.0.0.0]" ].each do |host|
      check = application_host_check(host: host, application_host: host)

      assert_equal :warning, check[:status], host
      assert_includes check[:detail], host
      assert_includes check[:detail], "APPLICATION_HOST"
    end
  end

  test "運用環境で外部から到達できる公開 URL は確認済みとして扱う" do
    [ "officeweave.example.com", "portal.internal", "192.0.2.10", "[2001:db8::10]",
      "[::ffff:192.0.2.10]" ].each do |host|
      check = application_host_check(host: host)

      assert_equal :ok, check[:status], host
      assert_equal host, check[:detail]
    end
  end

  test "公開ポートを指定している場合はホスト名と合わせて示す" do
    check = application_host_check(host: "officeweave.example.com", port: 8443)

    assert_equal :ok, check[:status]
    assert_equal "officeweave.example.com:8443", check[:detail]
  end

  test "公開 URL のホスト名が無い場合は注意として扱う" do
    check = application_host_check(host: nil)

    assert_equal :warning, check[:status]
    assert_includes check[:detail], "APPLICATION_HOST"
  end

  test "運用環境以外では localhost を注意として扱わない" do
    check = application_host_check(host: "localhost", environment: "test")

    assert_equal :ok, check[:status]
  end

  test "秘密情報へ既知の初期値が残っている場合は注意として扱う" do
    check = with_environment("DATABASE_PASSWORD" => "change_me") { check_named("秘密情報の初期値") }

    assert_equal :warning, check[:status]
    assert_includes check[:detail], "DATABASE_PASSWORD"
  end

  test "既知の初期値は表記が違っても見つける" do
    check = with_environment("DATABASE_PASSWORD" => "CHANGE_ME",
                             "SMTP_PASSWORD" => " officeweave ") { check_named("秘密情報の初期値") }

    assert_equal :warning, check[:status]
    assert_includes check[:detail], "DATABASE_PASSWORD"
    assert_includes check[:detail], "SMTP_PASSWORD"
  end

  # 値の強弱は問わない。強い値でも、これは管理者の平文パスワードである。
  # 空白だけの値も、パスワードとしては使えないが環境へは渡っている。
  test "初期利用者のパスワードが Rails の実行環境へ渡っていれば注意として扱う" do
    [ "r0-t13-strong-seed-password", "change_me" ].each do |value|
      check = with_environment("INITIAL_USER_PASSWORD" => value) { check_named("初期利用者の資格情報") }

      assert_equal :warning, check[:status], "#{value.inspect} を見逃した"
      assert_includes check[:detail], "INITIAL_USER_PASSWORD"
      assert_not_includes check[:detail], value
    end
  end

  test "空白だけの初期利用者のパスワードも渡っているものとして扱う" do
    [ " ", "\t", "　" ].each do |value|
      check = with_environment("INITIAL_USER_PASSWORD" => value) { check_named("初期利用者の資格情報") }

      assert_equal :warning, check[:status], "#{value.inspect} を見逃した"
    end
  end

  test "初期利用者のパスワードが未設定または空文字なら確認済みとして扱う" do
    [ nil, "" ].each do |value|
      check = with_environment("INITIAL_USER_PASSWORD" => value) { check_named("初期利用者の資格情報") }

      assert_equal :ok, check[:status], "#{value.inspect} を注意にした"
    end
  end

  # 残存の確認と、既知の初期値の確認は別の観点として分ける。
  test "初期利用者のパスワードは既知の初期値の確認へ含めない" do
    check = with_environment("INITIAL_USER_PASSWORD" => "change_me",
                             "DATABASE_PASSWORD" => "a-long-secret-value",
                             "SMTP_PASSWORD" => nil) { check_named("秘密情報の初期値") }

    assert_equal :ok, check[:status]
  end

  test "既知の初期値を Unicode の空白で囲んでも見つける" do
    check = with_environment("DATABASE_PASSWORD" => "\u3000\u3000officeweave\u3000\u3000",
                             "SMTP_PASSWORD" => "\u00A0\u00A0password\u00A0\u00A0") { check_named("秘密情報の初期値") }

    assert_equal :warning, check[:status]
    assert_includes check[:detail], "DATABASE_PASSWORD"
    assert_includes check[:detail], "SMTP_PASSWORD"
    assert_not_includes check[:detail], "officeweave"
    assert_not_includes check[:detail], "password"
  end

  # 診断の出力は画面にもログにも残る。原因を読むのに要るのは変数名だけである。
  test "秘密情報の値そのものは出力しない" do
    check = with_environment("DATABASE_PASSWORD" => "change_me") { check_named("秘密情報の初期値") }

    assert_not_includes check[:detail], "change_me"
  end

  test "既知の初期値でない秘密情報は確認済みとして扱う" do
    check = with_environment("DATABASE_PASSWORD" => "a-long-secret-value",
                             "SMTP_PASSWORD" => nil) { check_named("秘密情報の初期値") }

    assert_equal :ok, check[:status]
  end

  test "既知の初期値を使う管理者がいる場合は注意として扱う" do
    administrator = users(:taro)
    administrator.update_columns(password_digest: BCrypt::Password.create("officeweave"))

    check = check_named("管理者のパスワード")

    assert_equal :warning, check[:status]
    assert_includes check[:detail], administrator.email_address
  end

  test "管理者のパスワードの確認では digest も一致した値も出力しない" do
    users(:taro).update_columns(password_digest: BCrypt::Password.create("officeweave"))

    check = check_named("管理者のパスワード")

    assert_not_includes check[:detail], "officeweave"
    assert_not_includes check[:detail], users(:taro).reload.password_digest
  end

  test "無効にされた管理者は既知の初期値の確認から外す" do
    users(:hanako).update!(role: "administrator")
    users(:taro).update_columns(password_digest: BCrypt::Password.create("officeweave"),
                                deactivated_at: Time.current)

    assert_equal :ok, check_named("管理者のパスワード")[:status]
  end

  test "一般利用者は既知の初期値の確認から外す" do
    users(:hanako).update_columns(password_digest: BCrypt::Password.create("officeweave"))

    assert_equal :ok, check_named("管理者のパスワード")[:status]
  end

  # 外部の方式で認証している間は、保存済みのパスワードでログインできない。
  test "外部認証を使う設定では保存済みのパスワードを確認しない" do
    users(:taro).update_columns(password_digest: BCrypt::Password.create("officeweave"))
    Authentication::ProviderRegistry.register(PasswordlessProvider)

    check = with_environment("AUTHENTICATION_PROVIDER" => "passwordless") { check_named("管理者のパスワード") }

    assert_equal :ok, check[:status]
  ensure
    Authentication::ProviderRegistry.instance_variable_get(:@providers).delete("passwordless")
  end

  # パスワードを求めない外部方式の代わりとして使う。
  class PasswordlessProvider
    def self.name_key = "passwordless"
    def self.password_required? = false
    def self.authenticate(email_address:, password:) = User.find_by(email_address: email_address)
  end

  private
    # 開始待ちの thread を解放し、止まるまで見届ける。
    #
    # kill は停止を指示するだけで、そこで終わったことにはならない。
    # 指示のあとにもう一度 join し、それでも生きているものだけを返す。
    def release_and_join_storage_threads(threads, start)
      threads.count(&:alive?).times { start << true }

      threads.filter_map do |thread|
        next if thread.join(CLEANUP_TIMEOUT)

        thread.kill
        thread.join(CLEANUP_TIMEOUT)

        thread if thread.alive?
      end
    end

    # 保存先の後片付けは、この試験だけが使うディレクトリで確かめる。
    #
    # テストは process 単位で並列に走り、どの process も同じ tmp/storage を使う。
    # 共有の保存先を丸ごと見ると、別 process が正しく使っている最中のプローブまで
    # 「残った」と数えてしまう。
    #
    # 差し替えのための依存は増やさない。標準の設定を書き換え、ensure で元へ戻す。
    def with_isolated_storage_root
      Dir.mktmpdir("officeweave-diagnostics-") do |directory|
        saved_service = ActiveStorage::Blob.service
        root = Pathname(directory)

        begin
          ActiveStorage::Blob.service = Struct.new(:root).new(root)

          yield root
        ensure
          ActiveStorage::Blob.service = saved_service
        end
      end
    end

    def find(name)
      @checks.find { |check| check[:name] == name }
    end

    def check_named(name)
      Diagnostics.new.run.find { |check| check[:name] == name }
    end

    # 環境変数は実行時に読む。書き換えたものは、失敗しても必ず元へ戻す。
    def with_environment(values)
      saved = values.keys.index_with { |name| ENV[name] }
      values.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }

      yield
    ensure
      saved.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
    end

    # メールの設定と実行環境を明示して、公開 URL の確認だけを取り出す。
    #
    # 差し替えのための依存は増やさない。いずれも標準の設定であり、
    # 書き換えたものは ensure で必ず元へ戻す。
    def application_host_check(host:, port: nil, environment: "production", application_host: nil)
      options = { protocol: "https" }
      options[:host] = host if host
      options[:port] = port if port

      saved_options = ActionMailer::Base.default_url_options
      saved_environment = Rails.env
      saved_host = ENV["APPLICATION_HOST"]

      ActionMailer::Base.default_url_options = options
      Rails.env = environment
      application_host.nil? ? ENV.delete("APPLICATION_HOST") : ENV["APPLICATION_HOST"] = application_host

      Diagnostics.new.run.find { |check| check[:name] == "メール本文の URL" }
    ensure
      ActionMailer::Base.default_url_options = saved_options
      Rails.env = saved_environment
      saved_host.nil? ? ENV.delete("APPLICATION_HOST") : ENV["APPLICATION_HOST"] = saved_host
    end
end
