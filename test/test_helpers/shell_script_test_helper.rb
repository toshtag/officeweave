require "open3"
require "tmpdir"

# シェルスクリプトを、実際に実行して確かめるための足場。
#
# バックアップと復元は外部コマンドの組み合わせで成り立っており、
# Ruby へ移しても検証の対象は変わらない。実物をそのまま動かして確かめる。
#
# データベースと Docker は、この場では用意しない。
# 代わりに、同じ名前の実行ファイルを PATH の先頭へ置いて呼び出しを受け止める。
# 検証したいのはスクリプトの分岐と後始末であり、外部コマンドの動作ではない。
module ShellScriptTestHelper
  # 作業用のディレクトリと、偽の外部コマンドを置く場所を用意する。
  def with_shell_sandbox
    Dir.mktmpdir("officeweave-shell") do |root|
      bin = File.join(root, "fake-bin")
      work = File.join(root, "work")
      FileUtils.mkdir_p([ bin, work ])

      yield Sandbox.new(root: root, fake_bin: bin, work: work)
    end
  end

  Sandbox = Struct.new(:root, :fake_bin, :work, keyword_init: true) do
    # 偽の外部コマンドを置く。中身は呼び出し側が決める。
    def install_command(name, body)
      path = File.join(fake_bin, name)
      File.write(path, body)
      FileUtils.chmod(0o755, path)
      path
    end

    def path(*parts)
      File.join(work, *parts)
    end

    def read(*parts)
      File.read(path(*parts))
    end

    def exist?(*parts)
      File.exist?(path(*parts))
    end

    # 作業ディレクトリを現在地としてスクリプトを実行する。
    #
    # 書庫を標準出力へ流す経路だけは binary: true とする。
    # それ以外は日本語のメッセージを比較するため、UTF-8 として扱う。
    def run(script, *arguments, env: {}, stdin_data: nil, chdir: work, binary: false)
      command = [ Rails.root.join(script).to_s, *arguments ]

      stdout, stderr, status = Open3.capture3(
        environment(env),
        *command,
        stdin_data: stdin_data || "",
        binmode: true,
        chdir: chdir
      )

      stdout = stdout.dup.force_encoding(Encoding::UTF_8) unless binary

      [ stdout, stderr.dup.force_encoding(Encoding::UTF_8), status ]
    end

    private
      def environment(extra)
        {
          "PATH" => "#{fake_bin}:#{ENV['PATH']}",
          # 呼び出しの記録先。偽の外部コマンドが書き足す。
          "FAKE_LOG" => File.join(root, "calls.log")
        }.merge(extra.transform_values(&:to_s))
      end
  end

  # 書き出しに成功する pg_dump。
  PG_DUMP_SUCCESS = <<~SCRIPT
    #!/bin/bash
    echo "pg_dump $*" >> "${FAKE_LOG}"
    for argument in "$@"; do
      case "${argument}" in
        --file=*) output="${argument#--file=}" ;;
      esac
    done
    echo "-- 取得したデータベースの内容" > "${output}"
  SCRIPT

  # 失敗する pg_dump。
  PG_DUMP_FAILURE = <<~SCRIPT
    #!/bin/bash
    echo "pg_dump $*" >> "${FAKE_LOG}"
    echo "データベースへ接続できません" >&2
    exit 1
  SCRIPT

  # 問い合わせにも復元にも応える psql。
  PSQL = <<~SCRIPT
    #!/bin/bash
    echo "psql $*" >> "${FAKE_LOG}"
    for argument in "$@"; do
      case "${argument}" in
        --command=SELECT*) echo "20260101000000" ;;
      esac
    done
    exit 0
  SCRIPT

  # 呼び出しの記録。
  def calls(sandbox)
    log = File.join(sandbox.root, "calls.log")
    File.exist?(log) ? File.read(log) : ""
  end
end
