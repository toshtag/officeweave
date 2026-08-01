require "test_helper"

module Authentication
  # 起動そのものの検査。
  #
  # 既に起動しているテストプロセスの中で current を呼んでも、
  # 「起動しない」ことは確かめられない。別のプロセスを実際に起動し、
  # 終了状態と出力を外側から見る。
  class ProviderBootTest < ActiveSupport::TestCase
    include BootProcessTestHelper

    test "設定が無い場合は内部認証で起動する" do
      status, output = boot(nil)

      assert_predicate status, :success?, output
      assert_includes output, "BOOTED:internal"
    end

    test "内部認証を明示した場合は起動する" do
      status, output = boot("internal")

      assert_predicate status, :success?, output
      assert_includes output, "BOOTED:internal"
    end

    test "知らない名前が指定された場合は起動しない" do
      status, output = boot("does-not-exist")

      assert_not_predicate status, :success?, output
      assert_not_includes output, "BOOTED:"
      assert_includes output, "AUTHENTICATION_PROVIDER"
      assert_includes output, "does-not-exist"
      assert_includes output, "internal"
      assert_not_includes output, "内部認証を使用します"
    end

    test "空文字が指定された場合は起動しない" do
      status, output = boot("")

      assert_not_predicate status, :success?, output
      assert_not_includes output, "BOOTED:"
      assert_includes output, %(AUTHENTICATION_PROVIDER="")
    end

    test "同じ識別子を別の実装が名乗る場合は起動しない" do
      status, output = boot_with_conflicting_provider

      assert_not_predicate status, :success?, output
      assert_not_includes output, "BOOTED:"
      assert_includes output, "DuplicateProviderName"
      assert_includes output, "internal"
    end

    private
      RESOLVE = 'puts "BOOTED:#{Authentication::ProviderRegistry.current.name_key}"'

      # 内部認証と同じ識別子の方式を、登録の並びへ割り込ませる。
      #
      # bin/rails runner の script は初期化を終えてから走るため、
      # 初期化そのものへは届かない。初期化の前に to_prepare を積む。
      CONFLICTING_BOOT = <<~RUBY
        class ConflictingBootProvider
          def self.name_key = "internal"
        end

        require_relative "config/application"

        Rails.application.config.to_prepare do
          Authentication::ProviderRegistry.register(ConflictingBootProvider)
        end

        Rails.application.initialize!

        #{RESOLVE}
      RUBY

      # 認証方式を指定して Rails を起動する。
      # nil を渡した場合は、環境変数そのものを子プロセスへ渡さない。
      def boot(provider)
        spawn_boot([ "bin/rails", "runner", RESOLVE ], provider)
      end

      def boot_with_conflicting_provider
        spawn_boot([ "ruby", "-e", CONFLICTING_BOOT ], nil)
      end

      def spawn_boot(command, provider)
        environment = { "RAILS_ENV" => "test", "AUTHENTICATION_PROVIDER" => provider }

        # シェルを介さず引数のまま渡す。設定値が語の区切りとして解釈されない。
        boot_process(command, environment)
      end
  end
end
